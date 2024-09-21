/*
 * Globals
 */

let plotData;                   // Raw data - gets transformed into runStatus
let runStatus;                  // Status of run - plotnames, times, etc.
let soundings = {};		// soundings parameters

let regionIdx = {};		// Region to Regions index conversion
let curRegion;                  // Current region name
let curModel;                   // Current model
let curDate;                    // Current date
let curTime;                    // Current time being displayed
let timeIdx;                    // times/cache index for current time
let curPlot;                    // Name of current plot
let curSounding;                // Current sounding selection if active
let baseRef;                    // Plots path - region/date/model
let runLoc;                     // Reference to current row in runStatus
let plotWasCentered = false;    // True if plot was previously centered

// Google map info
let map;                        // Google map reference
let zoom = 7;                   // initial zoom
let overlay;                    // Overlay object reference
let airspaceFiles = [];		// array of airspace file names (.kmz/.kml)
let airspaceBaseUrl;		// airspace base url
let airspace = [];		// array of airspace layers
let initialRegion;		// initial region to display
let markerArray = [];
let setCenter;                  // LatLng object for desired center
let bounds;                     // Google bounds object
let infoArray = [];             // popup info window
let wasLong = false;            // Tracks whether left-click was long

// Opacity globals
let opacity = 50;               // initial value
let OPACITY_MAX_PIXELS = 57;    // Width of opacity control image
let knobCreated = false;        // knob creation status

let RASPoverlay;

async function getRASPoverlay() {
    module = await import("./RASPoverlay.js");
    RASPoverlay = module.RASPoverlay;
}

/*
 * Initialization
 */
function initIt()
{
    getRASPoverlay();
    setSize();

    map = newMap();

    getURL("current.json", baseDataAndMenu)
    window.onresize = function() {setSize();}
    
    // google maps event processing
    new LongClick(map, 2000);                   // long click processing
    google.maps.event.addListener(map, 'click',      function(event) { click(event); });
    // R-Click and longpress do the same thing
    google.maps.event.addListener(map, 'rightclick', function(event) { newclick(event); });
    google.maps.event.addListener(map, 'longpress',  function(event) { newclick(event); });
    
    setInterval(loadRunStatus, 120*1000);        // Update every other minute
}

function getUrl() {
    var newUrl = location.href;
    newUrl = newUrl.replace(/\?.*/,"");
    var center = map.getCenter();
    newUrl += "?region=" + curRegion;
    newUrl += "&model=" + curModel;
    newUrl += "&plot=" + curPlot;
    newUrl += "&zoom=" + map.getZoom();
    newUrl += "&center=" + center.lat() + "," + center.lng();
    location.href = newUrl;
}

function getUrlParameter(name) {
    name = name.replace(/[\[]/, '\\[').replace(/[\]]/, '\\]');
    var regex = new RegExp('[\\?&]' + name + '=([^&#]*)');
    var results = regex.exec(location.search);
    return results === null ? '' : decodeURIComponent(results[1].replace(/\+/g, ' '));
};

// Load/Update runStatus and build menu
function baseDataAndMenu(URL, data)
{
    baseData(URL, data)
    processPlotParams();

    // add airspace
    for (idx in airspaceFiles)
    {
	addKmlLayer(airspaceFiles[idx]);
    }
}

// Add the KmlLayer
function addKmlLayer(fname)
{
    var layer = new google.maps.KmlLayer({
	url: airspaceBaseUrl + fname,
	preserveViewport: true,
	map: map});

    google.maps.event.addListener(layer, "status_changed", function() {
	var kmlstatus = layer.getStatus();
	if (kmlstatus != 'OK') {
	    console.log("KmlLayer " + layer.getUrl() + " " + kmlstatus);
	} else {
	    airspace.push(layer);
	}
    });
}

// Load/Update runStatus
function loadRunStatus()
{
    getURL("current.json", baseData)
}

// Async get a URL
function getURL(URL, routine) {
    var xmlhttp = new XMLHttpRequest();
    xmlhttp.onreadystatechange = function() {
        if (xmlhttp.readyState == 4)
        {
            if (xmlhttp.status == 200 || xmlhttp.status == 0) {
                var data = JSON.parse(xmlhttp.responseText);
                routine(URL, data);
            } else {
                console.log("Failed runstatus: " + xmlhttp.status + " - " + xmlhttp.statusText);
            }
        }
    }
    // Add date to URL to bypass cache
    xmlhttp.open("GET", URL+"?"+(new Date()).getTime(), true);
    xmlhttp.send();
}

// base status file processing - contains regions and dates to process, and soundings info
function baseData(URL, data)
{
    plotData = data.regions;
    airspaceFiles = data.airspace.files;
    airspaceBaseUrl = data.airspace.baseUrl;
    initialRegion = data.initialRegion;
    if (airspaceBaseUrl == "") airspaceBaseUrl = location.href;
    airspaceBaseUrl = airspaceBaseUrl.replace(/[^/\\]+\.\w+$/,"");
    // create models for each region
    for (idx = 0; idx < plotData.length; idx++)
    {
	plotData[idx].models = [];
	soundings[plotData[idx].name] = plotData[idx].soundings;
    }
    // download valid times for each region/date
    for (idx = 0; idx < plotData.length; idx++)
    {
	var region = plotData[idx].name;
	var dates = plotData[idx].dates;
	regionIdx[region] = idx;
        for (i = 0; i < dates.length; i++)
        {
            var path = [region, dates[i], "status.json"];
            var dateURL = path.join("/");
            getURL(dateURL, dateStatus);
        }
    }
}

// date status file processing - for a date contains models, times, corners and centers
function dateStatus(URL, data)
{
    var path = URL.split("/");
    var file = path.pop();
    var date = path.pop();
    var region = path.pop();
    
    // Add times to plotData
    var dates = plotData[regionIdx[region]].dates;
    for (var i = 0; i < dates.length; i++)
    {
        if (date === dates[i])
        {
            plotData[regionIdx[region]].models[i] = data.models;
            break;
        }
    }
    
    // Check if all status has been retrieved
    for (var idx = 0; idx < plotData.length; idx++)
    {
	var dates = plotData[idx].dates;
	var models = plotData[idx].models;
	if (dates.length != models.length)
	    return;
        for (var i = 0; i < models.length; i++)
        {
            if (models[i] == undefined)
                return;         // not yet
        }
    }
    // console.log("All date status retrieved at " + Date());
    newRunStatus = swizzleStatus();
    processRunStatus(newRunStatus);
}

// Swizzle plotStatus into runStatus
function swizzleStatus()
{
    var newRunStatus = [];
    for (var idx = 0; idx < plotData.length; idx++)
    {
	region = plotData[idx].name;
        newRunStatus[region] = [];
        for (var i = 0; i < plotData[idx].printDates.length; i++)
        {
            var displayDate = plotData[idx].printDates[i];
            var date = plotData[idx].dates[i];
	    var models = plotData[idx].models[i];
	    for (var modelIdx = 0; modelIdx < models.length; modelIdx++)
            {
                var entry = plotData[idx].models[i][modelIdx];
		var model = entry.name;
                if (newRunStatus[region][model] == undefined)
                {
                    newRunStatus[region][model] = [];
                }
                entry["displayDate"] = displayDate;
                entry["date"] = date;
                newRunStatus[region][model].push(entry);
            }
        }
    }
    return newRunStatus;
}

// Load plot parameters
function processPlotParams() {
    var plotList = "";
    var plotDesc = "";
    var plotCount = -1;
    var requestedPlot = 0;		// default plot is the first one
    initialPlot = getUrlParameter("plot");
    for (i = 0; i < plotsList.length; i++)
    {
        var plot = plotsList[i];
        var params = paramList[plot];
        var c = params[0];
        if (c.indexOf("comment") >= 0)
        {
            c += " w3-red";
        } else {
            c += " plot";
	    plotCount += 1;
        }
        if (c.indexOf("full") >= 0)
        {
            c += " w3-show";
        }
        if (plot.indexOf("sounding") >= 0)
        {
            for (region in soundings)
            {
                var list = soundings[region];
		if (typeof list !== 'undefined')
		{
		    plotList += '<div id="' + region + '_soundings" class="w3-hide">\n';
		    plotList += '<li value="'+plot+'" class="list '+c+'">'+params[1]+'</li>\n';
		    for (j = 0; j < list.length; j++)
		    {
			plotList += '<li value="' + 'sounding' + (j+1) + '" class="list sounding">'+list[j].location+'</li>\n';
			plotDesc += '<p id="plot_'+plot+'" class="w3-hide">'+params[2]+'</p>\n';
		    }
		    plotList += '</div>\n';
		}
            }
        } else {
            plotList += '<li value="'+plot+'" class="list '+c+'">'+params[1]+'</li>\n';
            plotDesc += '<p id="plot_'+plot+'" class="w3-hide">'+params[2]+'</p>\n';
	    if (plot == initialPlot)
	    {
		requestedPlot = plotCount;
	    }
        }
    }
    $("#plotId").html(plotList);
    $("#plotInfo").html(plotDesc);
    $(".plot").click(function() {selectPlot(this);});
    $(".sounding").click(function() { selectSounding(this);});
    // Go to short list
    togglePlots();
    // Select and enable the plot
    $("#plotId").prop('selectedIndex', requestedPlot);;
    selectPlot($("#plotId > .plot")[requestedPlot]);
}

// Build menu HTML from runStatus
function processRunStatus(newStatus) {
    var regionText = "";
    var modelText = "";
    var dayText = "";
    var timeText = "";
    
    cleanCache(newStatus);
    runStatus = newStatus;
    if (curRegion == undefined)
    {
        // First call - get initial settings
	curRegion = getUrlParameter("region");
	curModel = getUrlParameter("model");
	zoom = getUrlParameter("zoom");
	var center=getUrlParameter("center");

	if (curRegion == "") {
	    curRegion = initialRegion;
	}
	if (runStatus[curRegion] == undefined) {
	    curRegion = Object.keys(runStatus).sort()[0];
	}
	if (curModel == "") {
	    curModel = Object.keys(runStatus[curRegion]).sort()[0];
	}
	if (zoom) {
	    map.setZoom(parseInt(zoom));
	}
	if (center) {
	    var coords = center.split(",");
	    setCenter = new google.maps.LatLng(parseFloat(coords[0]), parseFloat(coords[1]));
	    plotWasCentered = true;
	    map.panTo(setCenter);
	}
        if (runStatus[curRegion][curModel][0] != undefined)
            curDate = runStatus[curRegion][curModel][0]["date"];
        curTime = "1200";
        setSoundingMarkers(curRegion);
    }
    for (var region in runStatus)
    {
        regionText += '<li value="#'+region+'" class="rgn list">'+region+'</li>\n';
        
        // Sorted list of models
        sorted = Object.keys(runStatus[region]).sort();
        
        // Build models menu
        modelText += '<ul id="'+region+'" class="w3-btn-group w3-hide" style="margin:0;padding:0">\n';
        for (var idx = 0; idx < sorted.length; idx++)
        {
            var model = sorted[idx];
            var modelLink = region + '_' + model;
            modelText += '<button value="#'+modelLink+'" class="mdl w3-btn">'+model+'</button>\n';
            
            // Create date list
            dayText += '<ul id="'+modelLink+'" class="w3-ul w3-hoverable w3-hide">\n';
            for (var i = 0; i < runStatus[region][model].length; i++)
            {
                var dayLink = modelLink + '_' + i;
                var info = runStatus[region][model][i];
                dayText += '<li link="#'+dayLink+'" class="day w3-small" value="'+
                    region+"/"+info.date+"/"+model+'" date="'+info.date+'">'+info.displayDate+'</li>\n';
                
                // Create time list
                timeText += '<ul id="'+dayLink+'" class="w3-ul w3-hoverable w3-hide" style="height:126px;overflow:auto">\n';
                for (var j = 0; j < info.times.length; j++)
                {
                    var s = info.times[j];
                    var n = s.search(/\d/);
                    s = s.substring(n);
                    var c = n > 0 ? "old" : "";
                    timeText += '<li class="time w3-small '+c+'" value="'+j+'">'+s+'</li>\n';
                }
                // If no current cache, create one
                if (info.cache == undefined)
                {
                    var cache = [];
                    for (var j = 0; j < info.times.length; j++)
                    {
                        cache[j] = "";
                    }
                    info.cache = cache;
                }
                timeText += '</ul>\n';
            }
            dayText += '</ul>\n';
        }
        modelText += '</ul>';
    }
    // Update the html
    $("#regions").html(regionText);
    $("#models").html(modelText);
    $("#days").html(dayText);
    $("#times").html(timeText);
    // (re)activate the events
    $(".rgn").click(function() {curRegion = $(this).text();
	plotWasCentered = false;
	setSoundingMarkers(curRegion);
	setRegion(this);});
    $(".mdl").click(function() {curModel = $(this).text();
	setModel(this);});
    $(".day").click(function() {curDate = $(this).attr("date");
	setDay(this);});
    $(".time").click(function() {curTime = $(this).text();
	setTime(this);});
    // set the region
    setRegion( $("#regions > *:contains('"+curRegion+"')") );
}

// Copy image cache as appropriate to newStatus
function cleanCache(newStatus)
{
    if (runStatus == undefined) return;
    for (var region in newStatus)
    {
        if (runStatus[region] == undefined) continue;
        for (var model in newStatus[region])
        {
            if (runStatus[region][model] == undefined) continue;
            for (var d_new = 0; d_new < newStatus[region][model].length; d_new++)
            {
                var newRow = newStatus[region][model][d_new];
                // Look for matching date in old
                for (var d_old = 0; d_old < runStatus[region][model].length; d_old++)
                {
                    var oldRow = runStatus[region][model][d_old];
                    if (oldRow == undefined) continue;
                    if (newRow.date === oldRow.date)
                    {
                        if (oldRow.cache == undefined) break;
                        // Found date - make new cache
                        oldCache = oldRow.cache;
                        newCache = [];
                        for (var i=0; i<oldCache.length; i++)
                        {
                            newCache[i] = oldRow.times[i] === newRow.times[i] ? oldCache[i] : "";
                        }
                        for (var i = oldCache.length; i < newRow.times.length; i++)
                        {
                            newCache[i] = "";
                        }
                        newRow.cache = newCache;
                        break;
                    }
                }
            }
        }
    }
}

// Set/change region
function setRegion(region) {
    var rgn = $(region).text();
    $("#Region").text(rgn);
    var node = $("#regions > .active");
    for (var i = 0; i < node.length; i++)
    {
        node[i].className = node[i].className.replace(" active", "");
        var name = node[i].getAttribute("value");
        var cls = $(name).attr("class").replace("w3-show", "w3-hide");
        $(name).attr("class", cls);
    }
    // Turn off all soundings choices in menu
    node = $("#plotId > div");
    for (var i = 0; i < node.length; i++)
    {
        node[i].className = node[i].className.replace("w3-show", "w3-hide");
    }
    var now = $(region).attr("value");
    // console.log("change to region: " + now);
    $(region).attr("class", $(region).attr("class") + " active");
    $(now).attr("class", $(now).attr("class").replace("w3-hide", "w3-show"));
    if ($(now+"_soundings").length !== 0)
    {
        var cls = $(now+"_soundings").attr("class").replace("w3-hide", "w3-show");
        $(now+"_soundings").attr("class", cls);
    }
    // Activate the model
    var model = $(now + " > :contains('" + curModel + "')");
    if (model.length)
    {
        setModel(model);
    } else {
        var x = $(now + " > *");
        setModel(x[0]);
    }
    closeRegionDropdown();
}

// Set/change models
function setModel(model) {
    // Turn off any active models
    var nodes = $("#models > .w3-show > .active");
    for (var i = 0; i < nodes.length; i++)
    {
        nodes[i].className = nodes[i].className.replace(" active", "");
    }
    // Turn off any active day groups
    nodes = $("#days > .w3-show");
    for (var i = 0; i < nodes.length; i++)
    {
        var cls = nodes[i].className.replace("w3-show", "w3-hide");
        nodes[i].className = cls;
    }
    var now = $(model).attr("value");
    // console.log("change to model: " + now);
    $(model).attr("class", $(model).attr("class") + " active");
    $(now).attr("class", $(now).attr("class").replace("w3-hide", "w3-show"));
    // Activate a day
    var day = $(now + " > [date='" + curDate + "']");
    if (day.length)
    {
        setDay(day);
    } else {
        var x = $(now + " > *");
        setDay(x[0]);
    }
}

// Set/change day
function setDay(day) {
    // Turn off any active days
    var nodes = $("#days > .w3-show > .active");
    for (var i = 0; i < nodes.length; i++)
    {
        nodes[i].className = nodes[i].className.replace(" active", "");
    }
    // Turn off any active time groups
    nodes = $("#times > .w3-show");
    for (var i = 0; i < nodes.length; i++)
    {
        var cls = nodes[i].className.replace("w3-show", "w3-hide");
        nodes[i].className = cls;
    }
    if (day == undefined)
    {
        clearImage();
        return;
    }
    var now = $(day).attr("link");
    // console.log("change to day: " + now);
    // Highlight day
    $(day).attr("class", $(day).attr("class") + " active");
    // Enable time group
    $(now).attr("class", $(now).attr("class").replace("w3-hide", "w3-show"));
    // Set globals
    baseRef = $(day).attr("value");
    var idx = now.substring(1).split("_");
    runLoc = runStatus[idx[0]][idx[1]][idx[2]];
    // Re-center plot if needed
    if ( ! plotWasCentered)
    {
        var coords = runLoc["center"];
        setCenter = new google.maps.LatLng(coords[0], coords[1]);
        plotWasCentered = true;
    }
    // Set time in new list
    var times = $(now + " > *");
    for (i = 0; i < times.length; i++)
    {
        if (times[i].innerHTML >= curTime)
        {
            setTime(times[i]);
            return;
        }
    }
    clearImage();
}

// Set/change time
function setTime(time) {
    var nodes = $("#times > .w3-show > .active");
    for (var i = 0; i < nodes.length; i++)
    {
        nodes[i].className = nodes[i].className.replace(" active", "");
    }
    time.className += " active";
    curTime = time.innerHTML;
    timeIdx = time.getAttribute("value");
    // console.log("New state: " + curRegion + "/" + curModel + "/" + curDate + "/" + curTime);
    if (curSounding != undefined)
    {
        selectSounding(curSounding);
    } else {
        updateImage();
    }
}

// Toggle plots list between brief list and full
function togglePlots() {
    var list = $("#plotId > .full");
    var from, to;
    if (list[0].className.indexOf("w3-show") >= 0)
    {
        from = "w3-show"; to = "w3-hide";
        $("#plotDetail").html("Short List");
    } else {
        from = "w3-hide"; to = "w3-show";
        $("#plotDetail").html("Full List");
    }
    for (i = 0; i < list.length; i++)
    {
        list[i].className = list[i].className.replace(from, to);
    }
}

// Disable current selection
function disableSelection() {
    var nodes = $("#plotId > .active");
    for (i = 0; i < nodes.length; i++)
    {
        nodes[i].className = nodes[i].className.replace(" active", "");
    }
    var infos = $("#plotInfo > .w3-show");
    for (i = 0; i < infos.length; i++)
    {
        infos[i].className = infos[i].className.replace("w3-show", "w3-hide");
    }
    var soundings = $('#' + curRegion + '_soundings > .active');
    for (i = 0; i < soundings.length; i++)
    {
	soundings[i].className = soundings[i].className.replace(" active", "");
    }
    curSounding = undefined;
}

// Select Plot
function selectPlot(plot) {
    // console.log("plot: " + plot.innerHTML);
    disableSelection();
    // Enable plots
    $("#imgDiv").attr("class", $("#imgDiv").attr("class").replace("w3-hide", "w3-show"));
    // Hide soundings
    $("#sounding").attr("class", $("#sounding").attr("class").replace("w3-show", "w3-hide"));
    plot.className += " active";
    var now = "#plot_" + plot.getAttribute("value");
    var cls = $(now).attr("class").replace("w3-hide", "w3-show");
    $(now).attr("class", cls);
    curPlot = plot.getAttribute("value");
    updateImage();
}

// Get timestamp for current selection
function getStamp() {
    var stamp = runLoc.cache[timeIdx];
    if (stamp === "")
    {
        var d = new Date();
        stamp = d.toTimeString().split(" ")[0];
        runLoc.cache[timeIdx] = stamp;
        // New image - info windows are invalid
        deleteInfo();
    }
    return stamp;
}

// Display a sounding
function selectSounding(sounding) {
    // console.log("Select sounding: " + sounding.getAttribute("value"));
    disableSelection();
    // Hide plots
    $("#imgDiv").attr("class", $("#imgDiv").attr("class").replace("w3-show", "w3-hide"));
    // Enable soundings
    $("#sounding").attr("class", $("#sounding").attr("class").replace("w3-hide", "w3-show"));
    sounding.className += " active";
    // Get timeStamp
    var stamp = getStamp();
    // Load the image
    var url = baseRef + "/" + sounding.getAttribute("value") + "." + curTime + "local.d2.png?" + stamp;
    $("#theSounding").attr("src", url);
    curSounding = sounding;
}

// Download and display new image(s)
function updateImage() {
    if (!(baseRef && curPlot))
    {
        return;
    }
    
    // Get timeStamp
    var stamp = getStamp();
    
    var imgURL = baseRef + "/" + curPlot + "." + curTime + "local.d2";
    // console.log("Image: " + imgURL);
    
    var titleURL = imgURL + ".head.png?" + stamp;
    if (titleURL === $("#theTitle").attr("src"))
    {
        // console.log("image didn't change");
        return;
    }
    deleteInfo();           // remove any info windows
    $("#theTitle").attr("src", imgURL + ".head.png?" + stamp);
    $("#theSideScale").attr("src", imgURL + ".side.png?" + stamp);
    $("#theScale").attr("src", imgURL + ".foot.png?" + stamp);
    var corners = runLoc.corners;
    bounds = new google.maps.LatLngBounds(
            new google.maps.LatLng(corners[0][0], corners[0][1]),
            new google.maps.LatLng(corners[1][0], corners[1][1]));
    overlay = new RASPoverlay(bounds, imgURL + ".body.png?" + stamp, map);

    if (!knobCreated)
    {
        createOpacityControl(map);
        knobCreated = true;
    }
    if (! plotWasCentered)
    {
        map.panTo(setCenter);
        plotWasCentered = true;
    }
}

// Remove plot from overlay
function clearImage() {
    $("#theTitle").attr("src", null);
    $("#theSideScale").attr("src", null);
    $("#theScale").attr("src", null);
    clearSoundingMarkers();
    overlay.clear();
}

// Configure imgage sizes
function setSize() {
    // window size
    var w = window.innerWidth
    || document.documentElement.clientWidth
    || document.body.clientWidth;
    
    var h = window.innerHeight
    || document.documentElement.clientHeight
    || document.body.clientHeight;
    
    var el = document.getElementById("nav");
    var wid = el.offsetWidth;
    var hgt = el.offsetHeight;
    
    // Net width
    w -= wid + 20;
    
    // sidebar width
    var sideWidth = w * .09;
    
    // remaining image width
    w -= sideWidth;
    
    // Height of title image
    var topHeight = w * 0.08;
    
    // Height of plot image & side bar
    var plotHeight = h - topHeight;
    
    // div widths handled by w3.col class
    var div = document.getElementById("topTitle");
    div.overflow = "hidden";
    div.style.height = topHeight + "px";
    
    div = document.getElementById("plotImg");
    div.overflow = "hidden";
    div.style.height = plotHeight + "px";
    
    div = document.getElementById("sideScale");
    div.overflow = "hidden";
    div.style.height = plotHeight + "px";
}

// Create a google map object
function newMap()
{
    var mapOptions = {
        zoom:               zoom,
        mapTypeId:          google.maps.MapTypeId.TERRAIN,
        scrollwheel:	    false,
        draggableCursor:    "crosshair",
        streetViewControl:  false,
        // overviewMapControl:  true,
        minZoom:            6,
        maxZoom:            12
    };
    
    map = new google.maps.Map(document.getElementById("plotImg"), mapOptions);

    return( map );
}

/*
 * map left-click processing - cycle through times
 */
function click(E)
{
    if (wasLong)
    {
        wasLong = false;
        return;
    }
    
    var newTime = $("#times > .w3-show > .active").next();
    if ( newTime.length == 0)
    {
        newTime = $("#times > .w3-show > *");
        console.log("wrapping to " + newTime.length);
    }
    setTime(newTime[0]);
}

/******************************************************
 * Check if plot is implemented
 *
 * Returns: "" if not implemented
 *          Parameter name, or
 *          Two Parameter names for Vector Parameters
 ******************************************************/
function checkParam()
{
    if (curPlot === "boxwmax" ) return "";
    if (curPlot.match(/^sounding/)) return "";
    
    /* Identify the Vector Params */
    if(curPlot === "wstar_bsratio")   return("wstar bsratio");
    if(curPlot === "zsfclclmask")     return("zsfclcldif zsfclcl");
    if(curPlot === "zblclmask")       return("zblcldif zblcl");
    if(curPlot === "sfcwind0")        return("sfcwind0spd sfcwind0dir");
    if(curPlot === "sfcwind")         return("sfcwindspd sfcwinddir");
    if(curPlot === "blwind")          return("blwindspd blwinddir");
    if(curPlot === "bltopwind")       return("bltopwindspd bltopwinddir");
    if(curPlot === "press1000")       return("press1000 press1000wspd press1000wdir");
    if(curPlot === "press950")        return("press950 press950wspd press950wdir");
    if(curPlot === "press850")        return("press850 press850wspd press850wdir");
    if(curPlot === "press700")        return("press700 press700wspd press700wdir");
    if(curPlot === "press500")        return("press500 press500wspd press500wdir");
    if(curPlot === "wind950")         return("wind950spd wind950dir");
    if(curPlot === "wind850")         return("wind850spd wind850dir");
    
    return curPlot;
}

/*
 * map right-click and long click
 */
function newclick(E)
{
    if( !bounds.contains(E.latLng)){ // Outside forecast area!
        return;
    }

    var str = E.latLng.toUrlValue();
    var lat = str.split(',')[0];
    var lon = str.split(',')[1];
    
    parameter = checkParam();
    
    if(parameter === "") {
        addInfo(E.latLng, "<pre>Values for " + document.getElementById("Param").value + "\n are not available</pre>");
        return;
    }
    {
        blipSpotUrl = "cgi/get_rasp_blipspot.cgi";

        tail =
          "region="      + curRegion
        + "&date="       + $("#days > .w3-show > .active").attr('date')
        + "&model="      + curModel
        + "&time="       + curTime
        + "&lat="        + lat
        + "&lon="        + lon
        + "&param="      + parameter ;
        ;
        // console.log("URL = " + blipSpotUrl + "\ntail = " + tail);
        doCallback(blipSpotUrl, tail, E);
    }
}

/*
 * Call a cgi script
 */
function doCallback(url, data, Event)
{
    /************************************************/
    /* This stuff needed if running from file://... */
    /* DELETE THE LINE BELOW TO INCLUDE  */
    /*
     try {
     netscape.security.PrivilegeManager.enablePrivilege("UniversalBrowserRead");
     } catch (e) {
     alert("Permission UniversalBrowserRead denied.");
     }
     */
    /* AND THE LINE ABOVE */
    // End This stuff needed
    /************************************************/
    var req = false;
    if (window.XMLHttpRequest) {
        try { req = new XMLHttpRequest(); }
        catch (e) { req = false; }
    }
    else if (window.ActiveXObject) {
        // For Internet Explorer on Windows
        try { req = new ActiveXObject("Msxml2.XMLHTTP"); }
        catch (e) {
            try { req = new ActiveXObject("Microsoft.XMLHTTP"); }
            catch (e) { req = false; }
        }
    }
    if (req) {
        req.onreadystatechange = function(){
            if(req.readyState == 4)
            {
                if (req.status == 200 || req.status == 0)
                {
                    addInfo(Event.latLng, '<pre>' + req.responseText + '</pre>');
                } else {
                    console.log("Failed cgi request");
                }
            }
        }
        try { req.open('POST', url, true); }
        catch (E){ alert(E); }
        req.setRequestHeader('Content-Type', 'application/x-www-form-urlencoded');
        req.send(data);
    }
    else { alert("Failed to send CGI data"); }
}

/*
 * Produce info popup window
 */
function addInfo(location, txt)
{
    var infoOpts;
    var longline = false;
    
    var nlines = 2; // Always need at least two lines to  prevent scroll bars
    var ind = 0;
    var longline = false;
    for(var start = 0; (ind = txt.indexOf("\n", start)) > -1; start++, nlines++){
        if(ind - start > 50)
            longline = true;
        start = ind;
    }
    // Deal also with html <br>'s
    for(var start = 0; (ind = txt.indexOf("<br>", start)) > -1; start++, nlines++){
        if(ind - start > 50)
            longline = true;
        start = ind;
    }
    
    if(longline)    // Allow for bottom scrollbar
        nlines++;
    txt1 = '<div style="height: ' + nlines + 'em;" >' + txt + '</div>';
    
    infoOpts = {
    position: location,
    map:      map,
    maxHeight: 50,
    content:  txt1
    };
    var infowindow = new google.maps.InfoWindow( infoOpts );
    infowindow.open(map);
    infoArray.push(infowindow);
    
    // This is a bit kludgy - Adjust *every* infowindow each time - but it seems to work!
    google.maps.event.addDomListenerOnce(
            infowindow, 'domready', function(event)
                                    {
                                         var arr = document.getElementsByTagName("pre");
                                         for(var e = 0; e < arr.length; e++)
                                         {
                                            arr[e].parentNode.parentNode.style.overflow = 'visible';
                                         }
                                    }, true
    );
}

// Support for long-press to get popup
function LongClick(map, length) {
    this.length_ = length;
    var me = this;
    me.map_ = map;
    google.maps.event.addListener(map, 'mousedown', function(e) { me.onMouseDown_(e) });
    google.maps.event.addListener(map, 'mouseup',   function(e) { me.onMouseUp_(e)   });
}

LongClick.prototype.onMouseUp_ = function(e) {
    var now = new Date;
    if (now - this.down_ > this.length_) {
        google.maps.event.trigger(this.map_, 'longpress', e);
        waslong = true;
    }
}

LongClick.prototype.onMouseDown_ = function() {
    this.down_ = new Date;
}

function menu_open() {
    document.getElementById("nav").style.display = "block";
}
function menu_close() {
    document.getElementById("nav").style.display = "none";
}
function closeRegionDropdown() {
    var x = document.getElementById("regions");
    x.className = x.className.replace(" w3-show", "");
}
function regionDropdown() {
    var x = document.getElementById("regions");
    if (x.className.indexOf("w3-show") == -1) {
        x.className += " w3-show";
    } else {
        x.className = x.className.replace(" w3-show", "");
    }
}

function createOpacityControl(map)
{
    var sliderImageUrl = "slider.png";
    
    // Create main div to hold the control.
    var opacityDiv = document.createElement('DIV');
    opacityDiv.setAttribute("style", "margin:5px;overflow-x:hidden;overflow-y:hidden;background:url(slider.png) no-repeat;width:71px;height:21px;cursor:pointer;");
    opacityDiv.setAttribute("class", "gmnoprint");	// Do not include on a printout
    
    // Create knob
    var opacityKnobDiv = document.createElement('DIV');
    opacityKnobDiv.setAttribute("style", "padding:0;margin:0;overflow-x:hidden;overflow-y:hidden;background:url(slider.png) no-repeat -71px 0;width:14px;height:21px;");
    opacityDiv.appendChild(opacityKnobDiv);
    
    opacityCtrlKnob = new ExtDraggableObject(opacityKnobDiv, {
                                             restrictY: true,
                                             container: opacityDiv
                                             });
    
    google.maps.event.addListener(opacityCtrlKnob, "drag", function () {
                                  setKnobOpacity(opacityCtrlKnob.valueX());
                                  });
    
    google.maps.event.addDomListener(opacityDiv, "click", function (e) {
                                     var left = findPosLeft(this);
                                     sliderPos = e.pageX - left - 5; // - 5 as we're using a margin of 5px on the div
                                     opacityCtrlKnob.setValueX(sliderPos);
                                     setKnobOpacity(opacityCtrlKnob.valueX());
                                     });
    
    map.controls[google.maps.ControlPosition.TOP_RIGHT].push(opacityDiv);
    
    // Set initial value
    var initialValue = OPACITY_MAX_PIXELS * (opacity/ 100);
    opacityCtrlKnob.setValueX(initialValue);
    setKnobOpacity(opacityCtrlKnob.valueX());
}

function setKnobOpacity(pixelX) {
    // Range = 0 to OPACITY_MAX_PIXELS
    opacity = (100 / OPACITY_MAX_PIXELS) * pixelX;
    if (opacity < 0)   opacity = 0;
    if (opacity > 100) opacity = 100;
    overlay.setOpacity();
}

function findPosLeft(obj) {
    var curleft = 0;
    if (obj.offsetParent) {
        do {
            curleft += obj.offsetLeft;
        } while (obj = obj.offsetParent);
        return curleft;
    }
    return undefined;
}

// Clear any existing markers
function clearSoundingMarkers()
{
    // Remove any previous markers
    for (i = 0; i < markerArray.length; i++)
    {
        markerArray[i].setMap(null);
        markerArray[i] = null;
    }
    markerArray.length = 0;
}

/* Install Soundings Markers */
function setSoundingMarkers(region)
{
    clearSoundingMarkers();
    
    // Install the markers - but only if needed
    if( soundings[region] == undefined )
    {
        return;
    }

    var siz    = 20;        // Marker diameter in pixels
    var anchor = siz / 2;
    var sndImg = new google.maps.MarkerImage(
                         "sndmkr.png",                   // url
                         new google.maps.Size(siz,siz),  // size
                         new google.maps.Point(0,0),   // origin
                         new google.maps.Point(anchor,anchor), // anchor
                         new google.maps.Size(siz,siz)   // scaledSize
                         );

    for(i = 0; i < soundings[region].length; i++ )
    {
	var loc = new google.maps.LatLng(soundings[region][i].latitude, soundings[region][i].longitude);
        var marker = new google.maps.Marker({
                        position:  loc,
                        title:     soundings[region][i].location,
                        icon:      sndImg,
                        optimized: false,
                        flat:      true,
                        map:       map,
                        content:   i
                        });
        addSoundingLink(marker, i);     // otherwise last value of i in loop is used in link ...
        markerArray.push(marker);
    }
}

function addSoundingLink(marker, n)
{
    google.maps.event.addListener(
        marker,
        'click',
        function(){
            ctrFlag = true;
            setCenter = map.getCenter();
            var sndURL = '<img src="' + baseRef + '/sounding' + (n+1) + '.'
                + curTime + 'local.d2.png" height=800 width=800>' ;
            var infowindow = new google.maps.InfoWindow( { content: sndURL });
            infoArray.push(infowindow);
            infowindow.open(map, marker);
            google.maps.event.addListener(
                infowindow,
                'closeclick',
                function(){map.panTo(setCenter); setCenter = null;}
            );
        }
    );
}

// Close any info windows

function deleteInfo()
{
    for(i  = 0; i < infoArray.length; i++) {
        infoArray[i].setMap(null);
    }
    infoArray.length = 0;
    if(setCenter){
        map.panTo(setCenter); // Centre the map if Sounding has scrolled it
        setCenter = null;
    }
}
