;; TO ALTER BL CROSS-SECTION PLOT SECTION
;; ALSO ALTERS BOXWMAX

if( Region .eq. "UK2+1" .or. Region .eq. "UK+0") then
    opts_w@ContourParameters = (/ -450., 450., 50. /)
else
    opts_w@ContourParameters = (/ -250., 250., 50. /)
end if

; Adjust top level of boxwmax & xbl
; blsectionztop = 18 ; Kft (unless  UNITS are "metric")
; blsectionztop = 6  ; Km  (if UNITS are "metric")

; Change horizontal extent of section 
span = 20 ; Km
  
; Select Contour Lines overlay
; contourLines = "thetac" ; Potential Temp (default)
; contourLines = "rh"     ; Relative Humidity

