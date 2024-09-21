// Overlay class
export class RASPoverlay extends google.maps.OverlayView
{
// Constructor
constructor(bounds, image, map)
{
    super();

    this.bounds_        = bounds;
    this.image_         = image;
    this.map_           = map;
    
    this.setMap(map);
}

// Clear the overlay
clear()
{
    this.setMap(null);
}

// called when map's panes are ready and overlay has been added to map
onAdd()
{
    // create div element to hold overlay
    var div = document.createElement("div") ;
    div.style.borderStyle = "none";
    div.style.borderWidth = "0px";
    div.style.position    = "absolute" ;
    
    // create img element
    var img = document.createElement("img");
    img.src          = this.image_;
    img.style.width  = "100%";
    img.style.height = "100%";
    img.style.position = "absolute";
    div.appendChild(img);
    
    this.div_ = div;
    
    // Add to the "overlayLayer" pane
    var panes = this.getPanes();
    if (panes.overlayLayer.childElementCount != 0)
    {
        panes.overlayLayer.replaceChild(div, panes.overlayLayer.childNodes[0])
    } else {
        panes.overlayLayer.appendChild(div);
    }
}

// draw the overlay
draw()
{
    var overlayProjection = this.getProjection();
    
    if(overlayProjection == undefined)
        return;
    
    var sw = overlayProjection.fromLatLngToDivPixel(this.bounds_.getSouthWest());
    var ne = overlayProjection.fromLatLngToDivPixel(this.bounds_.getNorthEast());
    
    // Position our DIV using our bounds
    if(this.div_ == null)
        return;
    this.div_.style.left   = Math.min(sw.x,  ne.x) + "px";
    this.div_.style.top    = Math.min(ne.y,  sw.y) + "px";
    this.div_.style.width  = Math.abs(sw.x - ne.x) + "px";
    this.div_.style.height = Math.abs(ne.y - sw.y) + "px";
    
    this.setOpacity();
}

// Remove the main DIV from the map pane
onRemove()
{
    this.div_.parentNode.removeChild(this.div_);
    this.div_ = null;
}

// Opacity utility functions
isVisible()
{
    return ( this.div_ ? ((this.div_.style.visibility == 'visible') ?  true : false ) : false);
}

hide()
{
    if(this.div_){
        this.div_.style.visibility = 'hidden';
    }
}

show()
{
    if(this.div_){
        this.div_.style.visibility = 'visible';
    }
}

toggle() {
    if (this.div_) {
        if (this.div_.style.visibility === 'hidden') {
            this.show();
        } else {
            this.hide();
        }
    }
};

toggleDOM() {
    if (this.getMap()) {
        // Note: setMap(null) calls OverlayView.onRemove()
        this.setMap(null);
    } else {
        this.setMap(this.map_);
    }
};

setOpacity()
{
    var c = opacity/100 ;
    var d = this.div_ ;
    
    if (d) {
        this.show();
        if (typeof(d.style.filter)       == 'string') { d.style.filter = 'alpha(opacity=' + opacity + ')'; } //IE
        if (typeof(d.style.KHTMLOpacity) == 'string') { d.style.KHTMLOpacity = c ; }
        if (typeof(d.style.MozOpacity)   == 'string') { d.style.MozOpacity = c ; }
        if (typeof(d.style.opacity)      == 'string') { d.style.opacity = c ; }
    }
}


getOpacity()
{
    var d = this.div_ ;
    if(d){
        if (typeof(d.style.filter)       == 'string') { d.style.filter = 'alpha(opacity=' + opacity + ');'; } //IE
        if (typeof(d.style.KHTMLOpacity) == 'string') { return(100 * d.style.KHTMLOpacity); }
        if (typeof(d.style.MozOpacity)   == 'string') { return(100 * d.style.MozOpacity);   }
        if (typeof(d.style.opacity)      == 'string') { return(100 * d.style.opacity);      }
    }
    return(undefined);
}
}
