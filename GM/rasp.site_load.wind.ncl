;;; TO ALTER WIND PLOT SECTION

; Constrain SfcWind (10m) *only* to 0-26 Kt in 2 Kt steps
;if(plot_param .eq. "sfcwind" ) then
	opts_ws@ContourParameters = (/ 2., 24., 2. /);
	; opts_ws@ContourParameters = (/ 0., 0., 1. /);
;end if

;if(    (plot_param .eq. "sfcwind")   \
;  .or. (plot_param .eq. "bltopwind") \
;  .or. (plot_param .eq. "blwind")    \
;  .or. (plot_param .eq. "blwindshear" ) )

;	opts_ws@colorMap = "pgwind"
;	; NB: #colours in colorMap file must be >=  #steps

;	opts_ws@ContourParameters = (/ 3., 21., 3. /);
;end if

; Constrain SfcWind0 (2m) *only* to 0-18 Kt in 2 Kt steps
if(plot_param .eq. "sfcwind0" ) then
	opts_ws@ContourParameters = (/ 2., 16., 2. /);
end if
