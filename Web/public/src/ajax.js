  var httpRequest = false;
  function showInfo(url,id,h) {
		httpRequest = false;
		var url = url + id;
// alert(url);
                 if (window.XMLHttpRequest) { // Mozilla, Safari,...
                     httpRequest = new XMLHttpRequest();
                     if (httpRequest.overrideMimeType) {
                         httpRequest.overrideMimeType('text/xml');
                     }
                 } else if (window.ActiveXObject) { // IE
                     try {
                         httpRequest = new ActiveXObject("Msxml2.XMLHTTP");
                     } catch (e) {
                         try {
                         httpRequest = new ActiveXObject("Microsoft.XMLHTTP");
                         } catch (e) {}
                     }
                 }
                 if (!httpRequest) {
                     	alert('Giving up :( Cannot create an XMLHTTP instance');
                     return false;
                 }
                 httpRequest.onreadystatechange = function() { processRequest(id,h); }
                 httpRequest.open('GET', url, true);
                 httpRequest.send(null);
            }
  	    function ShowLoadingMessage(str,id,h) {
		var dd = h ? h : id;
  			if (str==1) {
  				document.getElementById('show_'+dd).innerHTML = "<img src='/imgs/loading.gif'>";
  			} else {
  				document.getElementById('show_'+dd).innerHTML = "";
  			}
  	    }
            function processRequest(id,h) {
  		ShowLoadingMessage(1,id,h);
                if (httpRequest.readyState == 4 && id !=0) {
		  if (httpRequest.status == 200 || !httpRequest.status) {
		    ShowLoadingMessage(0,id,h);
		    var dd = h ? h : id;
		    var did = "show" + dd;
		    var c = "close_" + dd;
		    document.getElementById(did).style.display="block";
		    if (!h) { document.getElementById(c).style.display="inline" }
		    document.getElementById(did).innerHTML=httpRequest.responseText;
		  } else {
		    alert("Error loading page\n"+ httpRequest.status +":"+ httpRequest.statusText);
                  }
            }
  }
  function addValues(url,v) {
	  var alls="";
	  for (i=0; i<v.length;i++){
		  if(v[i].selected)
			  alls+="&"+v[i].value;	
		  }
	  alls = alls.substring(1);
	  filterPhenotypes(url,alls);
  }  
  function filterPhenotypes(url,id,div) {
//     		alert(id);
		var url = url + id;
// 		alert(url);
		if (window.XMLHttpRequest) { // Mozilla, Safari,...
                     httpRequest = new XMLHttpRequest();
                     if (httpRequest.overrideMimeType) {
                         httpRequest.overrideMimeType('text/xml');
                     }
                 } else if (window.ActiveXObject) { // IE
                     try {
                         httpRequest = new ActiveXObject("Msxml2.XMLHTTP");
                     } catch (e) {
                         try {
                         httpRequest = new ActiveXObject("Microsoft.XMLHTTP");
                         } catch (e) {}
                     }
                 }
                 if (!httpRequest) {
                     	alert('Giving up :( Cannot create an XMLHTTP instance');
                     return false;
                 }
                 httpRequest.onreadystatechange = function() { processRequestPh(id,div); }
                 httpRequest.open('GET', url, true);
                 httpRequest.send(null);
   }
  function ShowLoadingPh(str,id,div) {
    if (str==1) {
      document.getElementById(div).innerHTML = "<img src='/imgs/loading.gif'>";
    } else {
      document.getElementById(div).innerHTML = "";
    }
  }
  function processRequestPh(id,div) {
    ShowLoadingPh(1,id,div);
    if (httpRequest.readyState == 4 && id !=0) {
      if (httpRequest.status == 200 || !httpRequest.status) {
	ShowLoadingPh(0,id,div);
// 	document.getElementById('fieldload').innerHTML=httpRequest.responseText;
	document.getElementById(div).innerHTML=httpRequest.responseText;
      } else {
	alert("Error loading page\n"+ httpRequest.status +":"+ httpRequest.statusText);
      }
    }
  }
  
  function searchPhenotypes(url,extend,phenoprint,expr,div) {
      var id= '?extend='+extend+'&phenoprint='+phenoprint+'&experiment='+expr;
//       alert(id);
//       alert(url);
      filterPhenotypes(url,id,div);
	$(function()  {	      
	  alert("3");
	  $(table).trigger("update");
	  $(table).trigger("appendCache");    
	});
  }
  
  function hideInfo(id) {
  			var did = "show" + id;
			document.getElementById("close_"+id).style.display="none";
			document.getElementById(did).style.display="none";
			document.getElementById(did).innerHTML="";
  }
  function showPh(id) {
	  document.getElementById(id).style.display="block";
  }
  function hidePh(id) {
	  document.getElementById(id).style.display="none";
  }
