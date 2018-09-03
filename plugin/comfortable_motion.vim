"=============================================================================
" File: comfortable_motion.vim
" Author: Yuta Taniguchi
" Created: 2016-10-02
"=============================================================================

scriptencoding utf-8

if !exists('g:loaded_comfortable_motion')
    finish
endif
let g:loaded_comfortable_motion = 1

let s:save_cpo = &cpo
set cpo&vim


" Default parameter values
if !exists('g:comfortable_motion_interval')
  let g:comfortable_motion_interval = 1000.0 / 60
endif
if !exists('g:comfortable_motion_friction')
  let g:comfortable_motion_friction = 80.0
endif
if !exists('g:comfortable_motion_air_drag')
  let g:comfortable_motion_air_drag = 2.0
endif
if !exists('g:comfortable_motion_scroll_down_key')
  let g:comfortable_motion_scroll_down_key = "\<C-e>"
endif
if !exists('g:comfortable_motion_scroll_up_key')
  let g:comfortable_motion_scroll_up_key = "\<C-y>"
endif
if !exists('g:comfortable_reverse_direction_fraction')
  let g:comfortable_reverse_direction_fraction = 4
endif

" The state

function! s:tick(timer_id)
  if !exists('w:comfortable_motion_state')
    call comfortable_motion#init_state()
  endif
  let l:st = w:comfortable_motion_state  " This is just an alias for the global variable
  if abs(l:st.velocity) >= 1 || l:st.impulse != 0 " short-circuit if velocity is less than one
    let l:dt = g:comfortable_motion_interval / 1000.0  " Unit conversion: ms -> s

    " Compute resistance forces
    let l:vel_sign = l:st.velocity == 0
      \            ? 0
      \            : l:st.velocity / abs(l:st.velocity)
    let l:friction = -l:vel_sign * g:comfortable_motion_friction * 1  " The mass is 1
    let l:air_drag = -l:st.velocity * g:comfortable_motion_air_drag
    let l:additional_force = l:friction + l:air_drag

    " Update the state
    let l:st.delta += l:st.velocity * l:dt
    let l:st.velocity += l:st.impulse + (abs(l:additional_force * l:dt) > abs(l:st.velocity) ? -l:st.velocity : l:additional_force * l:dt)
    let l:st.impulse = 0

    " Scroll
    let l:int_delta = float2nr(l:st.delta >= 0 ? floor(l:st.delta) : ceil(l:st.delta))
    let l:st.delta -= l:int_delta
    if l:int_delta > 0
      execute "normal! " . string(abs(l:int_delta)) . g:comfortable_motion_scroll_down_key
    elseif l:int_delta < 0
      execute "normal! " . string(abs(l:int_delta)) . g:comfortable_motion_scroll_up_key
    else
      " Do nothing
    endif
    redraw
  else
    " Stop scrolling and the thread
    let l:st.velocity = 0
    let l:st.delta = 0
    call timer_stop(s:timer_id)
    unlet s:timer_id
  endif
endfunction

function! comfortable_motion#init_state()
  let w:comfortable_motion_state = {
  \ 'impulse': 0.0,
  \ 'velocity': 0.0,
  \ 'delta': 0.0,
  \ }
endfunction

function! comfortable_motion#flick(impulse)
  if !exists('w:comfortable_motion_state')
    call comfortable_motion#init_state()
  endif

  if !exists('s:timer_id')
    " There is no thread, start one
    let l:interval = float2nr(round(g:comfortable_motion_interval))
    let s:timer_id = timer_start(l:interval, function("s:tick"), {'repeat': -1})
  endif
  let l:st = w:comfortable_motion_state
  let curVel = l:st.velocity
  let l:vel_sign = l:st.velocity == 0
    \            ? 0
    \            : l:st.velocity / abs(l:st.velocity)
  if l:vel_sign > 0 && a:impulse < 0 || l:vel_sign < 0 && a:impulse > 0
    call comfortable_motion#init_state()
    let w:comfortable_motion_state.velocity = curVel / g:comfortable_reverse_direction_fraction
  else
    let w:comfortable_motion_state.impulse += a:impulse
  endif
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
