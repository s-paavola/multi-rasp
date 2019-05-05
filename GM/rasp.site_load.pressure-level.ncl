;;; TO ALTER RESSURE LEVEL PLOT SECTION
; PAULS - Change limits for feet/min

; NB: opts_bparam for contours
;     opts_w      for wind barbs

if( Region .eq. "UK2+1" ) then
    opts_bparam@ContourParameters = (/ -450., 450., 50. /)
else
    opts_bparam@ContourParameters = (/ -218.75, 218.75, 31.25 /)
end if


;if(    (plot_param .eq. "press850")   )
;if(    (plot_param .eq. "sfcwind")   \
;  .or. (plot_param .eq. "bltopwind") \
;  .or. (plot_param .eq. "blwind")    \
;  .or. (plot_param .eq. "blwindshear" ) )

;       opts_bparam@colorMap = "BlueDarkRed18" ; "pgwind"
;       ; NB: #colours in colorMap file must be >=  #steps

;       opts_bparam@ContourParameters = (/ 15., 255., 15. /);
;end if

