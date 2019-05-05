# Convert Paul's parmList file to mine

BEGIN { FS="\""; cnt = 0;
	paramList["hwcrit"] = "full";
	paramList["hbl"] = "full";
	paramList["dbl"] = "full";
	paramList["hglider"] = "full";
	paramList["bltopvariab"] = "full";
	paramList["zwblmaxmin"] = "full";
	paramList["sfcshf"] = "full";
	paramList["sfcsunpct"] = "full";
	paramList["sfctemp"] = "full";
	paramList["sfcdewpt"] = "full";
	paramList["mslpress"] = "full";
	paramList["sfcwind"] = "full";
	paramList["bltopwind"] = "full";
	paramList["blwindshear"] = "full";
	paramList["zsfclcldif"] = "full";
	paramList["zsfclcl"] = "full";
	paramList["zblcldif"] = "full";
	paramList["zblcl"] = "full";
	paramList["blcwbase"] = "full";
	paramList["blcloudpct"] = "full";
	paramList["rain1"] = "full";
	paramList["cape"] = "full";
	paramList["blicw"] = "full";
	paramList["press1000"] = "full";
	paramList["press950"] = "full";
	paramList["press850"] = "full";
	paramList["press700"] = "full";
	paramList["press500"] = "full";
	paramList["boxwmax"] = "full";
	paramList["topo"] = "full";
	paramList["stars"] = "full";
	paramList["starshg"] = "full";
	paramList["wind850"] = "full";
	paramList["wind950"] = "full";
	}

# Change template for full params
/\/\* *[0-9]/ { $2 = paramList[$4]; }

/\/\*.*sounding/ { cnt = cnt + 1; next; }
/\/\*SOUNDING/ { cnt = cnt + 1; next; }

/THERMAL/ { $4 = "nope_therm"; $2 = "comment"; }
/WIND/    { $4 = "nope_wind"; $2 = "comment"; }
/CLOUD/   { $4 = "nope_cloud"; $2 = "comment"; }
/WAVE/    { $4 = "nope_wave"; $2 = "comment full"; }
/SOUNDING/{ $4 = "nope_soundings"; $2 = "comment"; }
/MODEL/   { $4 = "nope_topo"; $2 = "comment full"; }

/var paramList/ { sub(/\[/, "[];", $0); }

/paramListFull/ { sub(/paramListFull/, "plotsList", $0); }

# Fix bad template
	{ sub(/optionBoldBlue/, "", $0); }

# Param line
/\/\* *[0-9]/ {
		desc=$8;
		for (i=9; i<NF; i++) desc = desc "\"" $i;
		print "paramList[\"" $4 "\"] = [\"" $2 "\", \"" $6 "\", \"" desc "\"];";
		names[cnt]=$4;
		cnt = cnt + 1;
		next;
	      }

# Delete paramListLite array
/paramListLite/ { deleting = 1; }

/^\];/ { if (deleting == 1) print $0; deleting = 0; next; }

deleting == 1 { next; }

# paramList index line
/paramList\[/ { split($0, a, /[\[\]]/);
		if (length(names[a[2]]) == 0) next;
		sub(/param.*\]/, "\"" names[a[2]] "\"", $0);
		print $0;
		next;}

{ print $0; }
