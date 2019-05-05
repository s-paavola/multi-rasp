;;; TO ALTER CONTOUR PARAMETER PLOT SECTION

;;; example of altering wstar parameter contour interval/coloring
;;; (for more details see "Change plot formatting" section at http://www.drjack.info/twiki/bin/view/RASPop/ProgramUserChanges
;;example:  if( plot_param .eq. "wstar" ) then
  ;;example=fixed_colors:  opts_bparam@ContourParameters = (/ 100., 800., 100. /)
  ;;example=autoset_colors:  opts_bparam@ContourParameters = (/ 0., 0., 0. /)
  ;;example=autoset_colors:  delete( opts_bparam@ContourParameters )
;;example:  end if

;;;; PAULS ;;;;


; If plotting takes a LOOONGG time, try this
if( isvar("Region")) then
  if( Region .eq. "UK2+1" .or. Region .eq. "UK2" ) then
    opts_plot@cnFillMode = "MeshFill"
  else
    opts_plot@cnFillMode = "AreaFill"
  end if
end if

if( plot_param .eq. "rain1" ) then
  opts_bparam@ContourParameters = (/ 0.1, 4.9, 0.1 /)
  ; opts_bparam@ExplicitLevels = (/ 0.0, 0.1, 0.33, 0.5, 0.75, 1.0, 3.30, 5.0, 7.50, 10.0 /)
end if

if( plot_param .eq. "wstar_bsratio" ) then
  opts_bparam@ContourParameters = (/ 175., 575., 25. /)
end if

if( plot_param .eq. "wstar" ) then
  opts_bparam@ContourParameters = (/ 175., 575., 25. /)
end if

;if(plot_param .eq. "wblmaxmin") then
;       opts_bparam@colorMap = "BlueDarkRed18" ; "pgwind"
;end if
