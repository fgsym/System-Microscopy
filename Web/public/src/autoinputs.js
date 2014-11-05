$(function () {
	$( "#gnm" ).select2({ dropdownCssClass:"4gnm"  }); 
	$( "#sc" ).select2({ dropdownCssClass:"4sc" }); 

	$("select[name=genome]").change(function () {
		$.ajax({
			url: '../form',
			beforeSend: function() { $('#fload').show(); },
			data: 'genome=' + $("#gnm").val(),
			complete: function() { $('#fload').hide(); },
			success: function(result) {
				$('#navtop').html(result);			
				$('#tabform').show();
				$('#fload').hide();
			}	
		});	
	});
	$("#sc").change(function () {
		if ($("#sc").val() != "") {
//	        $("input[name=phn]").prop('disabled', false);
			$('#phinput').show();
			$('#ontinput').hide();	        
		} else {
			$('#ontinput').show();
			$('#phinput').hide();
		}
	});
    $( "#g" ).select2({
		minimumInputLength: 1,	
		placeholder: "gene name or Ensembl ID",
		multiple:true,
		maximumSelectionSize: 1, 
		ajax: {
			url: auPaths.gpath,
            dataType: 'json',
            data: function (term, page) { return { string: term };	},
            results: function (data) 	{ return {results: data};	}
		},
		formatResult: function(data, container, query) {
			$("li.select2-result:empty").remove();			
			if ( data.title != undefined) {
				var text = data.name;
				var term = query.term;
				var markup=[];
				var imarkup=[];
				var marked = false;
				var match=text.toUpperCase().indexOf(term.toUpperCase()), tl=term.length;
				if (match<0 && imatch<0) {
					markup.push(text);
					var itext = data.id;
					var imatch=itext.toUpperCase().indexOf(term.toUpperCase()), itl=term.length; // to drag in ensIDs too	
					if (imatch<0) { 
						markup.push(text);
						return;
					} else {
						markup.push("<span id=inpn>gene "+ data.title +": </span>");
						markup.push(itext);
						markup.push("<span id=inpi>");
						markup.push(itext.substring(0, imatch));
						markup.push("<span class='select2-match'>");
						markup.push(itext.substring(imatch, imatch + itl));
						markup.push("</span>");	
						markup.push(itext.substring(imatch + itl, itext.length));				
						markup.push("</span>");
						return markup.join("");							
					}
				} else {
					markup.push("<span id=inpn>gene "+ data.title +": </span>");
					markup.push(text.substring(0, match));				
					markup.push("<span class='select2-match'>");
					markup.push(text.substring(match, match + tl));
					markup.push("</span>");
					markup.push(text.substring(match + tl, text.length));				
					markup.push("<span id=inpi>" + data.id + "</span>");
					return markup.join("");	
				}	
			}	
		},
		formatSelection: function(data) {return data.name;},
		escapeMarkup: function (m) { return m; },
		createSearchChoice: function (term, data) {
				return {id: term, name: term};
		}
    });
    $( "#o" ).select2({
		minimumInputLength: 1,
		placeholder: "attribute keywords",
		multiple:true,
		maximumSelectionSize: 1, 
		ajax: {
			url: auPaths.atpath,
            dataType: 'json',
            data: function (term, page) { return { string: term };	},
            results: function (data) 	{ return {results: data};	}
		},
		formatResult: function(data, container, query) {
			if ( data.name != "") {
				var text = data.name;
				var term = query.term;
				var markup=[];
				var marked = false;
				var match=text.toUpperCase().indexOf(term.toUpperCase()), tl=term.length;
				if (match<0) {
					markup.push(text);
					return;
				}
				markup.push(text.substring(0, match));
				markup.push("<span class='select2-match'>");
				markup.push(text.substring(match, match + tl));
				markup.push("</span>");
				markup.push(text.substring(match + tl, text.length));
				return markup.join("");					
			}	
		},
		formatSelection: function(data) {return data.name;},
		escapeMarkup: function (m) { return m; },
		createSearchChoice: function (term, data) {
				return {id: term, name: term};
		}
    });
    $( "#ph" ).select2({
		minimumInputLength: 1,
		placeholder: "phenotype original terms keywords",
		multiple:true,
		maximumSelectionSize: 4, 
		ajax: {
			url: auPaths.phpath,
            dataType: 'json',
            data: function (term) 	{ return { string: term, StdID: $("#sc").val() };	},
            results: function (data) 		{ return {results: data};				}
		},
		formatResult: function(data, container, query) {
			if ( data.name != undefined) {
				var text = data.name;
				var term = query.term;
				var markup=[];
				var marked = false;
				var match=text.toUpperCase().indexOf(term.toUpperCase()), tl=term.length;
				if (match<0) {
					markup.push(text);
					return;
				}
				markup.push("<div class='wrapthis'>");
				markup.push(text.substring(0, match));
				markup.push("<span class='select2-match'>");
				markup.push(text.substring(match, match + tl));
				markup.push("</span>");
				markup.push(text.substring(match + tl, text.length));
				markup.push("</div><div id=inpi>" + data.screen + "</div>");
				return markup.join("");	
			}	
		},
		formatSelection: function(data) {return data.name + ",";},
		escapeMarkup: function (m) { return m; },		
		createSearchChoice: function (term, data) {
				return {value: term};
		}		
    });
	var i;    
	$("#ont").each(function (i, select) {
		var select2 =  $( "#ont" ).select2({
			minimumInputLength: 1,
			placeholder: "phenotype ontology keywords",
			multiple:true,
			maximumSelectionSize: 1, 
			ajax: {
				url: auPaths.ontpath,
				dataType: 'json',
				data: function (term, page) { return { string: term, StdID: $("#sc").val() };	},
				results: function (data) 	{ return {results: data};	}
			},		
			formatResult: function(data, container, query) {
				$("li.select2-result:empty").remove();							
				if ( data.id != "-" ) {
					var px = data.class;
					px = px.length-1;
					var div =  data.div;
					var div_t = "_", li_t;
					var pl;					
					if (div == "e") { pl = 1+px; div_t = "s_minus s_hitarea act"; } // do not know now how to hidden kids otherwise must be s_plus
					if (div == "o") { pl = 1+px; div_t = "s_minus s_hitarea act"; }
					var spx=0;
					if (div_t == "_") { 
						spx=px; px=0;
					} 
					li_t = "pa";					
					if (data.id != "") { li_t += " pitem" } else { li_t += " nitem"; data.id = "" }	
					var text = data.name;
					var term = query.term;
					var markup=[];
					var marked = false;
					var match=text.toUpperCase().indexOf(term.toUpperCase()), tl=term.length;
					if (match<0) {
						markup.push("<div id ="+data.kids+" class='"+li_t+"' style='margin-left:"+12*px+"px'>");
						markup.push("<div class='" + div_t + "'></div><span style='padding-left:" + 12*spx +"px'></span> ");
						markup.push(text);
						markup.push("</div>");
						return markup.join("");
					}
					markup.push("<div id ="+data.kids+" class='"+li_t+"' style='margin-left:"+12*px+"px'>");
					markup.push("<div class='" + div_t + "'></div><span style='padding-left:" + 12*spx +"px'></span> ");
					markup.push(text.substring(0, match));					
					markup.push("<span class='select2-match'>");					
					markup.push(text.substring(match, match + tl));
					markup.push("</span>");
					markup.push(text.substring(match + tl, text.length));
					markup.push("</div>");					
					return markup.join("");						
				} 
			},	
			escapeMarkup: function (m) { return m; },
//			formatSelection: function(data) {return (data.id != "") ? data.name : null;},
			formatSelection: function(data) {return data.name },
			createSearchChoice: function (term, data) {
						return {value: term};
			}	
		}).data('select2');
		select2.onSelect = (function(fn) {
			return function(data, options) {
				var target;	
				if (options != null) {
					target = $(options.target);
				}
				var num = target.parent().attr('id');
				var pnum = target.parent().parent().attr('id');
				if (target && target.hasClass( 'act' )) {
						if ( target.hasClass('s_minus') ) {
							target.removeClass( 's_minus' );
							target.addClass( 's_plus' );
							$( "#"+pnum ).parent().nextAll(":lt("+num+")").css( "display", "none" );
						} else if ( target.hasClass('s_plus') ) {
							target.removeClass( 's_plus' );
							target.addClass( 's_minus' );
							$( "#"+pnum ).parent().nextAll(":lt("+num+")").css( "display", "block" );
						}
				} else {
					return fn.apply(this, arguments);
				}
			}
		})(select2.onSelect);
	});
});
function makeField(f) {
  if (!navigator.userAgent.match(/Konque/)) {
	if (f == "re") {
		document.getElementById('r').style.fontSize='small';
		document.getElementById('r').style.color = '#777';
		document.getElementById('r').value = ' reagent\'s Supplier ID';
	}
	if (f == "std") {
	document.getElementById('s').style.fontSize='small';
	document.getElementById('s').style.color = '#777';
	document.getElementById('s').value = ' keywords or authors or Accession ID';
	}
  }
}
function makeQuery(f) {
	document.getElementById(f).value='';
	document.getElementById(f).style.color = '#0F2B52';
}
