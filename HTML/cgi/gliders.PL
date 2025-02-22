### SET POLAR DATA - COEFFS AND WGTS
# Eric - downloaded from http://drjack.info/RASP/SCORER/rasp-uk.uk/SOFTWARE/cgi-bin/index.html
sub set_glider_data()
{
  ### SET POLAR COEFFS - W=a*V^2+b*V+c where a,b,c for V in km/hr and _negative_ W in m/s ala Reichmann,Herold,etc
  ###   to use V in m/s, W=a'*V^2+b'*V+c where a`=a/kmphr2mps^2 & b'=b/kmphr2mps & kmphr2mps=0.277778 
  ### SET WEIGHT INFO =  dry weight on which polar data based (kg)
  ### SET BALLAST INFO = liters of ballast can carry (1 liter = 1 kg!)
  ### START OF MY POLAR DATA
  ### Eric - Original polar data replaced by XCSOAR data (as of 11/3/23) converted to required format using Google sheet
  ###  https://docs.google.com/spreadsheets/d/11s6b0BEiOLh2ITzhs9nVlh9HWSmoBeUtlxkrAEwkKUs/edit#gid=523147011
     $polar_data{'206 Hornet'}     = '-0.00017,0.0244,-1.47' ; $weight_data{'206 Hornet'}     = '318' ; $ballast_data{'206 Hornet'}     = '100' ;
     $polar_data{'303 Mosquito'}     = '-0.000113333333333333,0.0129333333333333,-0.839999999999999' ; $weight_data{'303 Mosquito'}     = '450' ; $ballast_data{'303 Mosquito'}     = '0' ;
     $polar_data{'304CZ'}     = '-0.000277894568909211,0.0650793307722573,-4.66900202227785' ; $weight_data{'304CZ'}     = '310' ; $ballast_data{'304CZ'}     = '115' ;
     $polar_data{'401 Kestrel (17m)'}     = '-0.000123717948717949,0.0160288461538462,-1.0261858974359' ; $weight_data{'401 Kestrel (17m)'}     = '367' ; $ballast_data{'401 Kestrel (17m)'}     = '33' ;
     $polar_data{'604 Kestrel'}     = '-0.000306495314392945,0.0622128034931716,-3.83661950352588' ; $weight_data{'604 Kestrel'}     = '570' ; $ballast_data{'604 Kestrel'}     = '100' ;
     $polar_data{'AK-8'}     = '-0.000184394681451484,0.0330534044354452,-2.1280724600778' ; $weight_data{'AK-8'}     = '362' ; $ballast_data{'AK-8'}     = '100' ;
     $polar_data{'Antares 18S'}     = '-0.000203333333333333,0.0402333333333334,-2.53' ; $weight_data{'Antares 18S'}     = '350' ; $ballast_data{'Antares 18S'}     = '250' ;
     $polar_data{'Antares 18T'}     = '-0.00013,0.0211,-1.35' ; $weight_data{'Antares 18T'}     = '395' ; $ballast_data{'Antares 18T'}     = '205' ;
     $polar_data{'Antares 20E'}     = '-0.00011,0.0197,-1.39' ; $weight_data{'Antares 20E'}     = '530' ; $ballast_data{'Antares 20E'}     = '130' ;
     $polar_data{'Apis (13m)'}     = '-0.000163333333333333,0.0224333333333333,-1.35' ; $weight_data{'Apis (13m)'}     = '200' ; $ballast_data{'Apis (13m)'}     = '45' ;
     $polar_data{'Apis 2 (15m)'}     = '-0.000166666666666667,0.0225,-1.33333333333333' ; $weight_data{'Apis 2 (15m)'}     = '310' ; $ballast_data{'Apis 2 (15m)'}     = '0' ;
     $polar_data{'Arcus'}     = '-0.0000964285714285715,0.0161071428571429,-1.245' ; $weight_data{'Arcus'}     = '700' ; $ballast_data{'Arcus'}     = '185' ;
     $polar_data{'ASG-29 (18m)'}     = '-0.00014,0.0225,-1.371' ; $weight_data{'ASG-29 (18m)'}     = '355' ; $ballast_data{'ASG-29 (18m)'}     = '225' ;
     $polar_data{'ASG-29E (15m)'}     = '-0.000143333333333333,0.0260333333333333,-1.81' ; $weight_data{'ASG-29E (15m)'}     = '350' ; $ballast_data{'ASG-29E (15m)'}     = '200' ;
     $polar_data{'ASG-29E (18m)'}     = '-0.000131169102140883,0.0223318684471338,-1.44639843290089' ; $weight_data{'ASG-29E (18m)'}     = '400' ; $ballast_data{'ASG-29E (18m)'}     = '200' ;
     $polar_data{'ASH-25'}     = '-0.0000944090358331513,0.0128004792298091,-0.848432126153155' ; $weight_data{'ASH-25'}     = '750' ; $ballast_data{'ASH-25'}     = '121' ;
     $polar_data{'ASH-26'}     = '-0.0001,0.013,-0.860000000000001' ; $weight_data{'ASH-26'}     = '340' ; $ballast_data{'ASH-26'}     = '185' ;
     $polar_data{'ASH-26E'}     = '-0.000138773901044747,0.0224786122609897,-1.40900650502662' ; $weight_data{'ASH-26E'}     = '435' ; $ballast_data{'ASH-26E'}     = '90' ;
     $polar_data{'ASK-13'}     = '-0.000376556776556776,0.0583369963369963,-3.07802197802198' ; $weight_data{'ASK-13'}     = '456' ; $ballast_data{'ASK-13'}     = '0' ;
     $polar_data{'ASK-18'}     = '-0.000170246799795187,0.0178498699436764,-0.994101996927805' ; $weight_data{'ASK-18'}     = '310' ; $ballast_data{'ASK-18'}     = '0' ;
     $polar_data{'ASK-21'}     = '-0.000207297564875865,0.0282109901231882,-1.6222028259322' ; $weight_data{'ASK-21'}     = '468' ; $ballast_data{'ASK-21'}     = '0' ;
     $polar_data{'ASK-23'}     = '-0.000213333333333334,0.0299333333333334,-1.71' ; $weight_data{'ASK-23'}     = '330' ; $ballast_data{'ASK-23'}     = '0' ;
     $polar_data{'ASW-12'}     = '-0.000167420978704717,0.0235134865044915,-1.29280688511662' ; $weight_data{'ASW-12'}     = '394' ; $ballast_data{'ASW-12'}     = '189' ;
     $polar_data{'ASW-15'}     = '-0.000196080820945835,0.0304453345701078,-1.87395868504735' ; $weight_data{'ASW-15'}     = '349' ; $ballast_data{'ASW-15'}     = '91' ;
     $polar_data{'ASW-17'}     = '-0.000158821733219181,0.0270687328850961,-1.71717728740674' ; $weight_data{'ASW-17'}     = '522' ; $ballast_data{'ASW-17'}     = '151' ;
     $polar_data{'ASW-19'}     = '-0.0002261632142053,0.0419292976930264,-2.67820744235636' ; $weight_data{'ASW-19'}     = '363' ; $ballast_data{'ASW-19'}     = '125' ;
     $polar_data{'ASW-20'}     = '-0.00017678005971591,0.0320774989137369,-2.11044322426573' ; $weight_data{'ASW-20'}     = '377' ; $ballast_data{'ASW-20'}     = '159' ;
     $polar_data{'ASW-20BL'}     = '-0.000135420554288479,0.019510968277006,-1.25937148386205' ; $weight_data{'ASW-20BL'}     = '400' ; $ballast_data{'ASW-20BL'}     = '126' ;
     $polar_data{'ASW-22B'}     = '-0.0001360625,0.02075,-1.1907' ; $weight_data{'ASW-22B'}     = '597' ; $ballast_data{'ASW-22B'}     = '303' ;
     $polar_data{'ASW-22BLE'}     = '-0.000113333333333333,0.0169333333333333,-1.03' ; $weight_data{'ASW-22BLE'}     = '465' ; $ballast_data{'ASW-22BLE'}     = '285' ;
     $polar_data{'ASW-24'}     = '-0.000155172550860729,0.0246008115907894,-1.5695391838385' ; $weight_data{'ASW-24'}     = '350' ; $ballast_data{'ASW-24'}     = '159' ;
     $polar_data{'ASW-27'}     = '-0.000156896027621207,0.0280863082863621,-1.85077721042867' ; $weight_data{'ASW-27'}     = '365' ; $ballast_data{'ASW-27'}     = '165' ;
     $polar_data{'ASW-28 (15m)'}     = '-0.000139297711474659,0.0187245020398368,-1.11044444444445' ; $weight_data{'ASW-28 (15m)'}     = '310' ; $ballast_data{'ASW-28 (15m)'}     = '200' ;
     $polar_data{'ASW-28 (18m)'}     = '-0.000181691297208539,0.0264889983579639,-1.42413916256158' ; $weight_data{'ASW-28 (18m)'}     = '345' ; $ballast_data{'ASW-28 (18m)'}     = '190' ;
     $polar_data{'Blanik L13'}     = '-0.000587758752202846,0.0912503748125937,-4.3497248744049' ; $weight_data{'Blanik L13'}     = '472' ; $ballast_data{'Blanik L13'}     = '0' ;
     $polar_data{'Blanik L13-AC'}     = '-0.000322222222222222,0.048,-2.63111111111111' ; $weight_data{'Blanik L13-AC'}     = '500' ; $ballast_data{'Blanik L13-AC'}     = '0' ;
     $polar_data{'Blanik L23'}     = '-0.000392183288409704,0.0639797843665768,-3.47862533692723' ; $weight_data{'Blanik L23'}     = '510' ; $ballast_data{'Blanik L23'}     = '0' ;
     $polar_data{'Carat'}     = '-0.000223333333333333,0.0386333333333333,-2.46' ; $weight_data{'Carat'}     = '470' ; $ballast_data{'Carat'}     = '0' ;
     $polar_data{'Cirrus (18m)'}     = '-0.000226666666666667,0.0338666666666666,-1.86' ; $weight_data{'Cirrus (18m)'}     = '330' ; $ballast_data{'Cirrus (18m)'}     = '100' ;
     $polar_data{'DG-1000 (20m)'}     = '-0.000172023540063377,0.0251923947487551,-1.35753734721594' ; $weight_data{'DG-1000 (20m)'}     = '613' ; $ballast_data{'DG-1000 (20m)'}     = '160' ;
     $polar_data{'DG-100'}     = '-0.000196666666666667,0.0297666666666667,-1.74' ; $weight_data{'DG-100'}     = '300' ; $ballast_data{'DG-100'}     = '100' ;
     $polar_data{'DG-200'}     = '-0.000113333333333333,0.0159333333333334,-1.14' ; $weight_data{'DG-200'}     = '300' ; $ballast_data{'DG-200'}     = '120' ;
     $polar_data{'DG-300'}     = '-0.000111111111111111,0.0123333333333333,-0.828888888888888' ; $weight_data{'DG-300'}     = '310' ; $ballast_data{'DG-300'}     = '190' ;
     $polar_data{'DG-400 (15m)'}     = '-0.000122154241163032,0.0235539294271935,-1.85321204474614' ; $weight_data{'DG-400 (15m)'}     = '440' ; $ballast_data{'DG-400 (15m)'}     = '90' ;
     $polar_data{'DG-400 (17m)'}     = '-0.000105720636883353,0.0194865645469967,-1.50582239847178' ; $weight_data{'DG-400 (17m)'}     = '444' ; $ballast_data{'DG-400 (17m)'}     = '90' ;
     $polar_data{'DG-500 (20m)'}     = '-0.00015097194966617,0.024801892534691,-1.56162078928701' ; $weight_data{'DG-500 (20m)'}     = '659' ; $ballast_data{'DG-500 (20m)'}     = '100' ;
     $polar_data{'DG-600 (15m)'}     = '-0.000126666666666667,0.0198666666666666,-1.32' ; $weight_data{'DG-600 (15m)'}     = '327' ; $ballast_data{'DG-600 (15m)'}     = '180' ;
     $polar_data{'DG-800B (15m)'}     = '-0.0000860285037015019,0.0110785511104506,-0.877829931803193' ; $weight_data{'DG-800B (15m)'}     = '468' ; $ballast_data{'DG-800B (15m)'}     = '100' ;
     $polar_data{'DG-800B (18m)'}     = '-0.000121996824906381,0.0207790474719142,-1.43152983043101' ; $weight_data{'DG-800B (18m)'}     = '472' ; $ballast_data{'DG-800B (18m)'}     = '100' ;
     $polar_data{'DG-800S (15m)'}     = '-0.0000967813791283515,0.0110869137385055,-0.781093478736568' ; $weight_data{'DG-800S (15m)'}     = '370' ; $ballast_data{'DG-800S (15m)'}     = '150' ;
     $polar_data{'DG-800S (18m)'}     = '-0.000141731626614455,0.0207919879843365,-1.23339394817946' ; $weight_data{'DG-800S (18m)'}     = '350' ; $ballast_data{'DG-800S (18m)'}     = '150' ;
     $polar_data{'Dimona'}     = '-0.00024,0.0368,-2.57' ; $weight_data{'Dimona'}     = '670' ; $ballast_data{'Dimona'}     = '100' ;
     $polar_data{'Discus 2b'}     = '-0.000108771929824561,0.0190701754385965,-1.46315789473684' ; $weight_data{'Discus 2b'}     = '312' ; $ballast_data{'Discus 2b'}     = '200' ;
     $polar_data{'Discus 2c (18m)'}     = '-0.00019,0.0323,-1.9' ; $weight_data{'Discus 2c (18m)'}     = '377' ; $ballast_data{'Discus 2c (18m)'}     = '188' ;
     $polar_data{'Discus'}     = '-0.000154901960784314,0.0230686274509804,-1.42352941176471' ; $weight_data{'Discus'}     = '350' ; $ballast_data{'Discus'}     = '182' ;
     $polar_data{'Duo Discus'}     = '-0.0001422785609089,0.0238320534399327,-1.58526825163055' ; $weight_data{'Duo Discus'}     = '615' ; $ballast_data{'Duo Discus'}     = '80' ;
     $polar_data{'Duo Discus T'}     = '-0.0001422785609089,0.0238320534399327,-1.58526825163055' ; $weight_data{'Duo Discus T'}     = '615' ; $ballast_data{'Duo Discus T'}     = '80' ;
     $polar_data{'Duo Discus xT'}     = '-0.000133086419753086,0.0232234567901235,-1.60823456790123' ; $weight_data{'Duo Discus xT'}     = '700' ; $ballast_data{'Duo Discus xT'}     = '50' ;
     $polar_data{'EB 28'}     = '-0.0000833333333333334,0.0108333333333334,-0.710000000000001' ; $weight_data{'EB 28'}     = '670' ; $ballast_data{'EB 28'}     = '180' ;
     $polar_data{'EB 28 Edition'}     = '-0.0000666666666666667,0.00666666666666667,-0.47' ; $weight_data{'EB 28 Edition'}     = '670' ; $ballast_data{'EB 28 Edition'}     = '180' ;
     $polar_data{'G 102 Astir CS'}     = '-0.000212999560825648,0.0335617039964866,-2.01900527009222' ; $weight_data{'G 102 Astir CS'}     = '330' ; $ballast_data{'G 102 Astir CS'}     = '90' ;
     $polar_data{'G 102 Club Astir IIIb'}     = '-0.000247619047619048,0.0393333333333334,-2.15714285714286' ; $weight_data{'G 102 Club Astir IIIb'}     = '380' ; $ballast_data{'G 102 Club Astir IIIb'}     = '0' ;
     $polar_data{'G 102 Standard Astir III'}     = '-0.000211904761904762,0.0330833333333333,-1.88928571428571' ; $weight_data{'G 102 Standard Astir III'}     = '380' ; $ballast_data{'G 102 Standard Astir III'}     = '70' ;
     $polar_data{'G 103 Twin 2'}     = '-0.000173488440466804,0.0324079793602317,-2.30802975164778' ; $weight_data{'G 103 Twin 2'}     = '580' ; $ballast_data{'G 103 Twin 2'}     = '0' ;
     $polar_data{'G 104 Speed Astir'}     = '-0.000277841561423651,0.0481791044776119,-2.7156027554535' ; $weight_data{'G 104 Speed Astir'}     = '351' ; $ballast_data{'G 104 Speed Astir'}     = '90' ;
     $polar_data{'Genesis II'}     = '-0.00017910112654146,0.0299829482739103,-1.84585958362723' ; $weight_data{'Genesis II'}     = '374' ; $ballast_data{'Genesis II'}     = '151' ;
     $polar_data{'Glasfluegel 304'}     = '-0.000116666666666667,0.0161666666666667,-1.23' ; $weight_data{'Glasfluegel 304'}     = '305' ; $ballast_data{'Glasfluegel 304'}     = '145' ;
     $polar_data{'H-201 Std Libelle'}     = '-0.000173911714432333,0.0231731341284033,-1.4014586893613' ; $weight_data{'H-201 Std Libelle'}     = '304' ; $ballast_data{'H-201 Std Libelle'}     = '50' ;
     $polar_data{'H-205 Club Libelle'}     = '-0.000173333333333333,0.0201333333333334,-1.13' ; $weight_data{'H-205 Club Libelle'}     = '295' ; $ballast_data{'H-205 Club Libelle'}     = '0' ;
     $polar_data{'H-301 Libelle'}     = '-0.000341096713123992,0.0573115023549309,-3.05335066419991' ; $weight_data{'H-301 Libelle'}     = '300' ; $ballast_data{'H-301 Libelle'}     = '50' ;
     $polar_data{'IS-28B2'}     = '-0.000254166666666667,0.04175,-2.45333333333333' ; $weight_data{'IS-28B2'}     = '590' ; $ballast_data{'IS-28B2'}     = '0' ;
     $polar_data{'IS-29D2 Lark'}     = '-0.000186095268363621,0.0233916948276908,-1.29821679913287' ; $weight_data{'IS-29D2 Lark'}     = '360' ; $ballast_data{'IS-29D2 Lark'}     = '0' ;
     $polar_data{'Janus (18m)'}     = '-0.00015,0.0225,-1.46' ; $weight_data{'Janus (18m)'}     = '498' ; $ballast_data{'Janus (18m)'}     = '240' ;
     $polar_data{'Janus C FG'}     = '-0.000330803150746172,0.0733629605390332,-4.82042521051671' ; $weight_data{'Janus C FG'}     = '603' ; $ballast_data{'Janus C FG'}     = '170' ;
     $polar_data{'Janus C RG'}     = '-0.000138095238095238,0.0196666666666666,-1.25142857142857' ; $weight_data{'Janus C RG'}     = '519' ; $ballast_data{'Janus C RG'}     = '240' ;
     $polar_data{'JS-1B (18m)'}     = '-0.000137987012987013,0.0247402597402597,-1.63246753246753' ; $weight_data{'JS-1B (18m)'}     = '405' ; $ballast_data{'JS-1B (18m)'}     = '180' ;
     $polar_data{'JS-1C (21m)'}     = '-0.000133101851851852,0.0230555555555555,-1.4575' ; $weight_data{'JS-1C (21m)'}     = '441' ; $ballast_data{'JS-1C (21m)'}     = '180' ;
     $polar_data{'JS-3 (15m)'}     = '-0.000111111111111111,0.0188888888888889,-1.37777777777778' ; $weight_data{'JS-3 (15m)'}     = '350' ; $ballast_data{'JS-3 (15m)'}     = '158' ;
     $polar_data{'JS-3 (18m)'}     = '-0.000127777777777778,0.0237222222222222,-1.64444444444445' ; $weight_data{'JS-3 (18m)'}     = '398' ; $ballast_data{'JS-3 (18m)'}     = '158' ;
     $polar_data{'Ka 2b'}     = '-0.000293410293410294,0.0425541125541126,-2.38138528138528' ; $weight_data{'Ka 2b'}     = '418' ; $ballast_data{'Ka 2b'}     = '0' ;
     $polar_data{'Ka 4 Rhoenlerche'}     = '-0.000290909090909091,0.0256363636363636,-1.38727272727273' ; $weight_data{'Ka 4 Rhoenlerche'}     = '360' ; $ballast_data{'Ka 4 Rhoenlerche'}     = '0' ;
     $polar_data{'Ka 6CR'}     = '-0.000345652476785979,0.0429457430357938,-2.00141973697014' ; $weight_data{'Ka 6CR'}     = '310' ; $ballast_data{'Ka 6CR'}     = '0' ;
     $polar_data{'Ka 6E'}     = '-0.00025781734430225,0.0367531763342973,-2.05323781488446' ; $weight_data{'Ka 6E'}     = '310' ; $ballast_data{'Ka 6E'}     = '0' ;
     $polar_data{'Ka 7'}     = '-0.000305435305435305,0.0441341991341991,-2.4478354978355' ; $weight_data{'Ka 7'}     = '445' ; $ballast_data{'Ka 7'}     = '0' ;
     $polar_data{'Ka 8'}     = '-0.00036350808961662,0.0456321000315178,-2.14538475878764' ; $weight_data{'Ka 8'}     = '290' ; $ballast_data{'Ka 8'}     = '0' ;
     $polar_data{'L 33 Solo'}     = '-0.000273929429258662,0.0418434249325981,-2.36583110274837' ; $weight_data{'L 33 Solo'}     = '330' ; $ballast_data{'L 33 Solo'}     = '0' ;
     $polar_data{'LAK-12'}     = '-0.000138,0.0196,-1.17375' ; $weight_data{'LAK-12'}     = '430' ; $ballast_data{'LAK-12'}     = '190' ;
     $polar_data{'LAK-17 (15m)'}     = '-0.000126666666666667,0.0218666666666667,-1.52' ; $weight_data{'LAK-17 (15m)'}     = '285' ; $ballast_data{'LAK-17 (15m)'}     = '215' ;
     $polar_data{'LAK-17 (18m)'}     = '-0.0001,0.013,-0.860000000000001' ; $weight_data{'LAK-17 (18m)'}     = '295' ; $ballast_data{'LAK-17 (18m)'}     = '205' ;
     $polar_data{'LAK17a (15m)'}     = '-0.000156206372244108,0.0240713560024881,-1.45101631073329' ; $weight_data{'LAK17a (15m)'}     = '285' ; $ballast_data{'LAK17a (15m)'}     = '180' ;
     $polar_data{'LAK17a (18m)'}     = '-0.000255813953488372,0.0535813953488372,-3.45872093023256' ; $weight_data{'LAK17a (18m)'}     = '298' ; $ballast_data{'LAK17a (18m)'}     = '180' ;
     $polar_data{'LAK-19 (15m)'}     = '-0.000163333333333333,0.0254333333333333,-1.55' ; $weight_data{'LAK-19 (15m)'}     = '285' ; $ballast_data{'LAK-19 (15m)'}     = '195' ;
     $polar_data{'LAK-19 (18m)'}     = '-0.000126666666666667,0.0168666666666667,-1.02' ; $weight_data{'LAK-19 (18m)'}     = '295' ; $ballast_data{'LAK-19 (18m)'}     = '185' ;
     $polar_data{'LS-10s (15m)'}     = '-0.000146666666666667,0.0242666666666667,-1.6' ; $weight_data{'LS-10s (15m)'}     = '370' ; $ballast_data{'LS-10s (15m)'}     = '170' ;
     $polar_data{'LS-10s (18m)'}     = '-0.000136666666666667,0.0215666666666667,-1.37' ; $weight_data{'LS-10s (18m)'}     = '380' ; $ballast_data{'LS-10s (18m)'}     = '220' ;
     $polar_data{'LS-1c'}     = '-0.000214394022714847,0.0367310459718644,-2.39760282757504' ; $weight_data{'LS-1c'}     = '350' ; $ballast_data{'LS-1c'}     = '91' ;
     $polar_data{'LS-1f'}     = '-0.000183333333333333,0.0288333333333334,-1.8' ; $weight_data{'LS-1f'}     = '345' ; $ballast_data{'LS-1f'}     = '80' ;
     $polar_data{'LS-3 (17m)'}     = '-0.00023,0.0391,-2.22' ; $weight_data{'LS-3 (17m)'}     = '325' ; $ballast_data{'LS-3 (17m)'}     = '0' ;
     $polar_data{'LS-3'}     = '-0.000144565619520983,0.0232750245299104,-1.55422923804468' ; $weight_data{'LS-3'}     = '383' ; $ballast_data{'LS-3'}     = '121' ;
     $polar_data{'LS-4'}     = '-0.0002,0.035,-2.19' ; $weight_data{'LS-4'}     = '361' ; $ballast_data{'LS-4'}     = '121' ;
     $polar_data{'LS-5'}     = '-0.000152136752136752,0.0227820512820513,-1.30288461538461' ; $weight_data{'LS-5'}     = '461' ; $ballast_data{'LS-5'}     = '120' ;
     $polar_data{'LS-6 (15m)'}     = '-0.000106956859696852,0.0145218033424018,-1.04061173727166' ; $weight_data{'LS-6 (15m)'}     = '327' ; $ballast_data{'LS-6 (15m)'}     = '160' ;
     $polar_data{'LS-6 (18m)'}     = '-0.000120741028630652,0.0169407954398238,-1.05666925767587' ; $weight_data{'LS-6 (18m)'}     = '330' ; $ballast_data{'LS-6 (18m)'}     = '140' ;
     $polar_data{'LS-7wl'}     = '-0.000453980730977272,0.103507995802213,-6.58246356073479' ; $weight_data{'LS-7wl'}     = '350' ; $ballast_data{'LS-7wl'}     = '150' ;
     $polar_data{'LS-8 (15m)'}     = '-0.000119145928653796,0.0144864412453967,-0.940235836774169' ; $weight_data{'LS-8 (15m)'}     = '325' ; $ballast_data{'LS-8 (15m)'}     = '185' ;
     $polar_data{'LS-8 (18m)'}     = '-0.000157595908922981,0.0238502595811701,-1.40940694938653' ; $weight_data{'LS-8 (18m)'}     = '325' ; $ballast_data{'LS-8 (18m)'}     = '185' ;
     $polar_data{'Mini Nimbus'}     = '-0.000123333333333333,0.0156333333333333,-1.02' ; $weight_data{'Mini Nimbus'}     = '345' ; $ballast_data{'Mini Nimbus'}     = '155' ;
     $polar_data{'Nimbus 2'}     = '-0.000183904934103197,0.0318966433629081,-1.93144172955006' ; $weight_data{'Nimbus 2'}     = '493' ; $ballast_data{'Nimbus 2'}     = '159' ;
     $polar_data{'Nimbus 3'}     = '-0.000125964752651006,0.0169663795421024,-0.940907894200834' ; $weight_data{'Nimbus 3'}     = '527' ; $ballast_data{'Nimbus 3'}     = '159' ;
     $polar_data{'Nimbus 3DM'}     = '-0.0000998010952395415,0.0175263986597427,-1.26582910710385' ; $weight_data{'Nimbus 3DM'}     = '820' ; $ballast_data{'Nimbus 3DM'}     = '168' ;
     $polar_data{'Nimbus 3D'}     = '-0.0000887679096251666,0.0114114066030724,-0.750207172666068' ; $weight_data{'Nimbus 3D'}     = '712' ; $ballast_data{'Nimbus 3D'}     = '168' ;
     $polar_data{'Nimbus 3T'}     = '-0.000123978561518206,0.0180350314577605,-1.05621205848238' ; $weight_data{'Nimbus 3T'}     = '577' ; $ballast_data{'Nimbus 3T'}     = '310' ;
     $polar_data{'Nimbus 4'}     = '-0.000138724243920559,0.0216302574169807,-1.24609254446993' ; $weight_data{'Nimbus 4'}     = '597' ; $ballast_data{'Nimbus 4'}     = '303' ;
     $polar_data{'Nimbus 4DM'}     = '-0.000111450252666092,0.0200647921715763,-1.37195442676807' ; $weight_data{'Nimbus 4DM'}     = '820' ; $ballast_data{'Nimbus 4DM'}     = '168' ;
     $polar_data{'Nimbus 4D'}     = '-0.00014182351528105,0.0261255577806154,-1.66954946294953' ; $weight_data{'Nimbus 4D'}     = '743' ; $ballast_data{'Nimbus 4D'}     = '303' ;
     $polar_data{'Para Competition'}     = '-0.00185964912280702,0.139543859649123,-3.61368421052631' ; $weight_data{'Para Competition'}     = '100' ; $ballast_data{'Para Competition'}     = '0' ;
     $polar_data{'Para EN A/DHV1'}     = '-0.004,0.212,-3.884' ; $weight_data{'Para EN A/DHV1'}     = '100' ; $ballast_data{'Para EN A/DHV1'}     = '0' ;
     $polar_data{'Para EN B/DHV12'}     = '-0.00347717323327079,0.217898686679175,-4.50200125078174' ; $weight_data{'Para EN B/DHV12'}     = '100' ; $ballast_data{'Para EN B/DHV12'}     = '0' ;
     $polar_data{'Para EN C/DHV2'}     = '-0.00136402387041773,0.0648763853367434,-1.65549872122762' ; $weight_data{'Para EN C/DHV2'}     = '110' ; $ballast_data{'Para EN C/DHV2'}     = '4.19' ;
     $polar_data{'Para EN D/DHV23'}     = '-0.00208823529411765,0.142029411764706,-3.51288235294118' ; $weight_data{'Para EN D/DHV23'}     = '100' ; $ballast_data{'Para EN D/DHV23'}     = '0' ;
     $polar_data{'Pegase 101A'}     = '-0.000211904761904762,0.0337619047619047,-1.95875' ; $weight_data{'Pegase 101A'}     = '344' ; $ballast_data{'Pegase 101A'}     = '120' ;
     $polar_data{'Phoebus C'}     = '-0.00012,0.0124,-0.74' ; $weight_data{'Phoebus C'}     = '310' ; $ballast_data{'Phoebus C'}     = '150' ;
     $polar_data{'PIK-20B'}     = '-0.000154660941010684,0.0239654115563005,-1.52154817302731' ; $weight_data{'PIK-20B'}     = '354' ; $ballast_data{'PIK-20B'}     = '144' ;
     $polar_data{'PIK-20D'}     = '-0.000190456341778308,0.0295812829371399,-1.74356487593092' ; $weight_data{'PIK-20D'}     = '348' ; $ballast_data{'PIK-20D'}     = '144' ;
     $polar_data{'PIK-20E'}     = '-0.000119773997281601,0.0125912187567695,-0.771116512163913' ; $weight_data{'PIK-20E'}     = '437' ; $ballast_data{'PIK-20E'}     = '80' ;
     $polar_data{'PIK-30M'}     = '-0.000136530243493973,0.0256782033490274,-1.86805886529211' ; $weight_data{'PIK-30M'}     = '460' ; $ballast_data{'PIK-30M'}     = '0' ;
     $polar_data{'Pilatus B4 FG'}     = '-0.000239197530864198,0.0295277777777778,-1.56700000000001' ; $weight_data{'Pilatus B4 FG'}     = '306' ; $ballast_data{'Pilatus B4 FG'}     = '0' ;
     $polar_data{'PW-5 Smyk'}     = '-0.000249241281103716,0.0320849557635652,-1.67490210522768' ; $weight_data{'PW-5 Smyk'}     = '300' ; $ballast_data{'PW-5 Smyk'}     = '0' ;
     $polar_data{'PW-6'}     = '-0.000327039930555556,0.0598263888888889,-3.53168055555556' ; $weight_data{'PW-6'}     = '546' ; $ballast_data{'PW-6'}     = '0' ;
     $polar_data{'R-26S Gobe'}     = '-0.000529166666666667,0.0770833333333334,-3.74' ; $weight_data{'R-26S Gobe'}     = '420' ; $ballast_data{'R-26S Gobe'}     = '0' ;
     $polar_data{'Russia AC-4'}     = '-0.000212846219457549,0.0293199182895626,-1.7326998676546' ; $weight_data{'Russia AC-4'}     = '250' ; $ballast_data{'Russia AC-4'}     = '0' ;
     $polar_data{'SF-27B'}     = '-0.00036,0.0562,-2.83' ; $weight_data{'SF-27B'}     = '300' ; $ballast_data{'SF-27B'}     = '0' ;
     $polar_data{'SGS 1-26E'}     = '-0.000340108509058292,0.0443231836444069,-2.38414445061525' ; $weight_data{'SGS 1-26E'}     = '315' ; $ballast_data{'SGS 1-26E'}     = '0' ;
     $polar_data{'SGS 1-34'}     = '-0.000258194256782158,0.036172890831986,-1.96603270301932' ; $weight_data{'SGS 1-34'}     = '354' ; $ballast_data{'SGS 1-34'}     = '0' ;
     $polar_data{'SGS 1-35A'}     = '-0.000203367233353398,0.030996182959919,-1.81836560348873' ; $weight_data{'SGS 1-35A'}     = '381' ; $ballast_data{'SGS 1-35A'}     = '179' ;
     $polar_data{'SGS 1-36 Sprite'}     = '-0.000338124476077685,0.0474817048656483,-2.33568072502473' ; $weight_data{'SGS 1-36 Sprite'}     = '322' ; $ballast_data{'SGS 1-36 Sprite'}     = '0' ;
     $polar_data{'SGS 2-33'}     = '-0.000298140278254053,0.046942083476216,-2.80390014941458' ; $weight_data{'SGS 2-33'}     = '470' ; $ballast_data{'SGS 2-33'}     = '0' ;
     $polar_data{'Silene E78'}     = '-0.000224773109243698,0.0305746218487395,-1.57674789915967' ; $weight_data{'Silene E78'}     = '450' ; $ballast_data{'Silene E78'}     = '0' ;
     $polar_data{'Skylark 4'}     = '-0.000232330018812147,0.028071351787154,-1.41306960494491' ; $weight_data{'Skylark 4'}     = '395' ; $ballast_data{'Skylark 4'}     = '0' ;
     $polar_data{'Std Austria S'}     = '-0.00016358024691358,0.0245030864197531,-1.61367283950617' ; $weight_data{'Std Austria S'}     = '297' ; $ballast_data{'Std Austria S'}     = '0' ;
     $polar_data{'Std Cirrus'}     = '-0.000242959939959861,0.0415534822957519,-2.50226395490781' ; $weight_data{'Std Cirrus'}     = '337' ; $ballast_data{'Std Cirrus'}     = '80' ;
     $polar_data{'Stemme S-10'}     = '-0.0000971758521079243,0.0123518235908521,-0.747483855557694' ; $weight_data{'Stemme S-10'}     = '850' ; $ballast_data{'Stemme S-10'}     = '0' ;
     $polar_data{'SZD-30 Pirat'}     = '-0.000237142857142857,0.0296857142857143,-1.57714285714286' ; $weight_data{'SZD-30 Pirat'}     = '370' ; $ballast_data{'SZD-30 Pirat'}     = '0' ;
     $polar_data{'SZD-36 Cobra'}     = '-0.000226017960698416,0.0335633005490177,-1.84333500835515' ; $weight_data{'SZD-36 Cobra'}     = '350' ; $ballast_data{'SZD-36 Cobra'}     = '30' ;
     $polar_data{'SZD-42 Jantar II'}     = '-0.00016464710917503,0.0268989862987423,-1.63127899892638' ; $weight_data{'SZD-42 Jantar II'}     = '482' ; $ballast_data{'SZD-42 Jantar II'}     = '191' ;
     $polar_data{'SZD-48-2 Jantar Std 2'}     = '-0.000213333333333334,0.0359333333333334,-2.19' ; $weight_data{'SZD-48-2 Jantar Std 2'}     = '375' ; $ballast_data{'SZD-48-2 Jantar Std 2'}     = '150' ;
     $polar_data{'SZD-48-3 Jantar Std 3'}     = '-0.000173294117647059,0.0290676470588235,-1.85744705882353' ; $weight_data{'SZD-48-3 Jantar Std 3'}     = '326' ; $ballast_data{'SZD-48-3 Jantar Std 3'}     = '150' ;
     $polar_data{'SZD-50 Puchacz'}     = '-0.0002,0.0230000000000001,-1.3' ; $weight_data{'SZD-50 Puchacz'}     = '435' ; $ballast_data{'SZD-50 Puchacz'}     = '135' ;
     $polar_data{'SZD-51-1 Junior'}     = '-0.000209090909090909,0.0248181818181818,-1.29272727272727' ; $weight_data{'SZD-51-1 Junior'}     = '333' ; $ballast_data{'SZD-51-1 Junior'}     = '0' ;
     $polar_data{'SZD-54-2 Perkoz (FT 17m) /* flat tip */'}     = '-0.000470914127423823,0.0829570637119114,-4.52713296398893' ; $weight_data{'SZD-54-2 Perkoz (FT 17m) /* flat tip */'}     = '442' ; $ballast_data{'SZD-54-2 Perkoz (FT 17m) /* flat tip */'}     = '0' ;
     $polar_data{'SZD-54-2 Perkoz (WL 17m) /* winglet */'}     = '-0.000483373997908679,0.0882339491111886,-4.85761240850471' ; $weight_data{'SZD-54-2 Perkoz (WL 17m) /* winglet */'}     = '442' ; $ballast_data{'SZD-54-2 Perkoz (WL 17m) /* winglet */'}     = '0' ;
     $polar_data{'SZD-54-2 Perkoz (WL 20m) /* long winglet */'}     = '-0.000420468115595892,0.0680966085502746,-3.40489491282541' ; $weight_data{'SZD-54-2 Perkoz (WL 20m) /* long winglet */'}     = '442' ; $ballast_data{'SZD-54-2 Perkoz (WL 20m) /* long winglet */'}     = '0' ;
     $polar_data{'SZD-55-1 Promyk'}     = '-0.00016,0.0252,-1.58' ; $weight_data{'SZD-55-1 Promyk'}     = '350' ; $ballast_data{'SZD-55-1 Promyk'}     = '200' ;
     $polar_data{'SZD-9 bis 1E Bocian'}     = '-0.000315714285714286,0.0420142857142857,-2.224' ; $weight_data{'SZD-9 bis 1E Bocian'}     = '540' ; $ballast_data{'SZD-9 bis 1E Bocian'}     = '0' ;
     $polar_data{'Taurus'}     = '-0.000226666666666667,0.0438666666666667,-2.83' ; $weight_data{'Taurus'}     = '472' ; $ballast_data{'Taurus'}     = '0' ;
     $polar_data{'Ventus 2c (18m)'}     = '-0.000154166666666667,0.0250833333333333,-1.52' ; $weight_data{'Ventus 2c (18m)'}     = '385' ; $ballast_data{'Ventus 2c (18m)'}     = '180' ;
     $polar_data{'Ventus 2cT (18m)'}     = '-0.000104,0.0144,-1.02' ; $weight_data{'Ventus 2cT (18m)'}     = '410' ; $ballast_data{'Ventus 2cT (18m)'}     = '110' ;
     $polar_data{'Ventus 2cx (18m)'}     = '-0.000154166666666667,0.0250833333333333,-1.52' ; $weight_data{'Ventus 2cx (18m)'}     = '385' ; $ballast_data{'Ventus 2cx (18m)'}     = '215' ;
     $polar_data{'Ventus 2cxT (18m)'}     = '-0.000116,0.0176,-1.16' ; $weight_data{'Ventus 2cxT (18m)'}     = '470' ; $ballast_data{'Ventus 2cxT (18m)'}     = '130' ;
     $polar_data{'Ventus a/b (16.6m)'}     = '-0.000154240943178151,0.0261361590211562,-1.71040096773638' ; $weight_data{'Ventus a/b (16.6m)'}     = '358' ; $ballast_data{'Ventus a/b (16.6m)'}     = '151' ;
     $polar_data{'Ventus b (15m)'}     = '-0.000130986398032134,0.0199609260739228,-1.37993564721248' ; $weight_data{'Ventus b (15m)'}     = '341' ; $ballast_data{'Ventus b (15m)'}     = '151' ;
     $polar_data{'Ventus cM (17.6)'}     = '-0.000100709691615192,0.0140766854132233,-0.999537621665646' ; $weight_data{'Ventus cM (17.6)'}     = '430' ; $ballast_data{'Ventus cM (17.6)'}     = '0' ;
     $polar_data{'VSO-10 Gradient'}     = '-0.000265476190476191,0.0426547619047619,-2.46857142857143' ; $weight_data{'VSO-10 Gradient'}     = '347' ; $ballast_data{'VSO-10 Gradient'}     = '0' ;
     $polar_data{'VT-116 Orlik II'}     = '-0.0003125,0.0387499999999999,-1.8' ; $weight_data{'VT-116 Orlik II'}     = '335' ; $ballast_data{'VT-116 Orlik II'}     = '0' ;
     $polar_data{'WA 26 P Squale'}     = '-0.000278180743606276,0.0452323769611004,-2.44823339780787' ; $weight_data{'WA 26 P Squale'}     = '330' ; $ballast_data{'WA 26 P Squale'}     = '0' ;
     $polar_data{'Zuni II'}     = '-0.00015493701630128,0.0195842201821213,-1.15952632278785' ; $weight_data{'Zuni II'}     = '358' ; $ballast_data{'Zuni II'}     = '182' ;
  ### END OF Eric DATA
  return;
}
# Do not delete the next line!
1.
