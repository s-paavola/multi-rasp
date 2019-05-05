#!/bin/bash

# Create the awk script
cat > $$.awk << '__EOF__'
/<\/?MultiGeometry>/ { next; }
/<Point>/ { isPoint = 1; next; }
isPoint == 1 { if ($1 == "</Point>") isPoint = 0; next; }

/<name>/ {
	    if (name == "") {
		split ($0, s, /[<>]/);
		name = s[3];
	    }
	 }

/<Folder>/ {
	     if (prefix == "") prefix = lines;
	     else if (lines != "") prefix = prefix "\n" lines;
	     lines = "";
	     name = "";
	   }

/<Placemark>/ && fname == "" {
	        gsub(/ /, "_", name);
		print name;
		fname = name ".kml";
		print prefix > fname;
		print lines >> fname;
		if (names != "") names = name "," names;
		else names = name;
		lines = "";
	    }

fname != "" {
	      print $0 >> fname;
	      if ($1 == "</Folder>") fname = "";
	      next;
	    }

{ if (lines != "") lines = lines "\n" $0;
  else lines = $0;}
END { 
      split (names, spaces, /,/);
      for (space in spaces) {
	  fname = spaces[space] ".kml";
	  print lines >> fname;
      }
    }
__EOF__

# Run the awk script to split the kml, and create the .kmz files
for f in `unzip -p allusa.* | awk -f $$.awk -`; do
  rm -f $f.kmz
  zip $f.kmz $f.kml
  rm $f.kml
done

# clean up
rm $$.awk
