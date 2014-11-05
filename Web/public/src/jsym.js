	$(document).ready(function () {
		function formatResult(row) {
			var r = row[0];
			r = r.replace(/(<.+?>.+?<.+?> )/gi, '');
			return r.replace(/ (<.+?>\(ENSG0.+?\)<.+?>)/gi, '');
		}
		function OformatResult(row) {
			var r = row[0];
			r = r.replace(/(<.+?>.+?<.+?> )/gi, '');
			return r;
		}
		$("#o").autocomplete('<%= $relpath %>/service/onto_autocomplete', { minChars: 1, max: 100, width: 325, selectFirst: false, formatResult: OformatResult});
		$("#o").result( function(event, data, formatted) {
			if (data)
				$(this).parent().next().find("input").val(data[0]);
		});

		$("#g").autocomplete('<%= $relpath %>/service/autocomplete', { minChars: 1, max: 100, width: 325, selectFirst: false, formatResult: formatResult});
		$("#g").result( function(event, data, formatted) {
			if (data)
				$(this).parent().next().find("input").val(data[1]);
		});

	});

	$(document).ready(function () { $('#phload').hide(); });
	$(document).ready(function () {
		$(".tablesorter").tablesorter({
		        // define a custom text extraction function
            		sortList: [[0,0]],
        		textExtraction: function(node) {
            // extract data from markup and return it
            			return node.childNodes[0].innerHTML;
        		},
			headers: { 1:{sorter: false}, 2:{sorter: false},
% for (my $i=4;$i<24;$i++) {
			<%= $i %>:{sorter: false},
% }
			24:{sorter: false}
			},
			widgets: ['stickyHeaders','zebra']
		});
		$("#ajax-face").change(function () {
			$.ajax({
				url: '<%= $relpath %>/search/loadpheno',
				beforeSend: function() { $('#phload').show(); },
				data: 'extend=' + $("#ajax-reload").is(':checked') +'&phenoprint=' + $("#ajax-pheno").val() +'&experiment='+ $("#ajax-exp").val() +'&face='+$(this).is(':checked'),
				complete: function() { $('#phload').hide(); },
				success: function(result) {
					$('#phenoload').html(result);
					$('#phload').hide();
					$(".tablesorter").tablesorter({
						textExtraction: function(node) {
						return node.childNodes[0].innerHTML;
						},
						widgets: ['zebra', 'stickyHeaders'],
						headers: { 1:{sorter: false}, 2:{sorter: false},
% for (my $i=4;$i<24;$i++) {
						<%= $i %>:{sorter: false},
% }
			24:{sorter: false}
						}
				});
				}
			});
		});
		$("#ajax-reload").change(function () {
			$.ajax({
				url: '<%= $relpath %>/search/loadpheno',
				beforeSend: function() { $('#phload').show(); },
				data: 'extend=' + $(this).is(':checked') + '&phenoprint=' + $("#ajax-pheno").val() +'&experiment='+ $("#ajax-exp").val() +'&face='+$("#ajax-face").is(':checked'),
				complete: function() { $('#phload').hide(); },
				success: function(result) {
					$('#phenoload').html(result);
					$('#phload').hide();
					$(".tablesorter").tablesorter({
						textExtraction: function(node) {
						return node.childNodes[0].innerHTML;
						},
						widgets: ['zebra', 'stickyHeaders'],
						headers: { 1:{sorter: false}, 2:{sorter: false},
% for (my $i=4;$i<24;$i++) {
						<%= $i %>:{sorter: false},
% }
			24:{sorter: false}
						}
					});
				}
			});
		});
	});

	function clearText(thefield){
	if (thefield.defaultValue==thefield.value)
	thefield.value = ""
	}
	function hideDiv(d) {
		document.getElementById(d).style.display = "none";
	}
	function showDiv(d) {
		document.getElementById(d).style.display = "block";
	}