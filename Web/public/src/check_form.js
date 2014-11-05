function clearText(thefield){
if (thefield.defaultValue==thefield.value)
  thefield.value = ""
} 

function checkLat(f,lat) {
    var checkPassRegex;
	if (!lat) {
		checkPassRegex = /[^(\040a-zA-Z0-9_\-\!\@\#\$\%\^\&\*\(\)\+\=\{\}\[\]\;\:\.\>\<\,\\\/\`\~\|)]/;
	} else {
		checkPassRegex = /[^(\040a-zA-Z0-9_\-)]/;
	}
    if (checkPassRegex.test(f.value)){
        f.style.color = "#CC0000";
	return true;
    } else{
        f.style.color = "";
	return false;
    }
}
function IsBlank(s)
{
	for(var i = 0; i < s.length; i++)
	{
		var c = s.charAt(i);
		if ((c != ' ') && (c != '\n') && (c != '\t')) return false;
	}
	return true;
}
function IfTrue(f) {
	var msg;
	var empty_fields = "";
	var empty_value = "";
	var falls =""
	var errors = "";
	var p1;
	var p2;
	var l;
	for(var i = 0; i < f.length; i++) {
		var e = f.elements[i];
		if(e.style){
			e.style.backgroundColor="#F0F0F0";
			e.style.Color="#000000";
		}
		if (e.required)	{
			if ((e.value == null) || (e.value == "") || IsBlank(e.value) || (e.value == "-")) {
					if(e.style){
						e.style.backgroundColor="#FFFFCC"
					}
					if (e.FieldName){
						empty_fields += "\n          " + e.FieldName
					} else {
						empty_fields += "\n          " + e.name;
						empty_value += "\n          " + e.value;
					}
					continue;
			}
		}
			if (e.required && (e.value != null) && (e.value != "") && !IsBlank(e.value) && (e.value != "-")) {
				var bads = false;
				if (e.name == 'login') {
					l = e.value;
					if (e.value.length < 2) {
						falls +=  "\n" + e.FieldName + " too short: Ђ" +e.value+ "ї Ч 1 symbol!";
					}
					bads = checkLat(e,0);
					if (bads) {
						falls +=  "\n" + e.FieldName + " Ч bad symbols !"
					}
				}
				if (e.name == 'passwd1' || e.name == 'passwd2') {
					if (e.value.length < 6) {
						falls +=  "\n" + e.FieldName + " too short: Ђ" +e.value+ "ї Ч  "  + e.value.length +countSmbls(e.value.length, " symbol", " symbols", " symbols");
					}
					bads = checkLat(e,0);
					if (bads) {
						falls +=  "\n" + e.FieldName + " Ч bad symbols!";
					}
				}
				if (e.name == 'passwd1') {	p1 = e.value;	continue;}
				if (e.name == 'passwd2') {	p2 = e.value;	continue;}
				if (e.name == 'email') {
					filter=/^([a-zA-Z0-9_\.\-])+\@(([a-zA-Z0-9\-])+\.)+([a-zA-Z0-9])+$/;
					(filter.test(e.value))?null:falls += "\n  " + e.FieldName + " email looks unreal !	";
				}
				if (falls) {	if (e.style){	e.style.backgroundColor="#FFFFCC"} }
				continue;
			}
		}
	if (l != null && l !="" && !IsBlank(l)) {
		if (p1 != p2) {
			falls +=  "\n" + "passwords mismatch !";
		}
		if (l != "" && p1!="" && (p1 == l || p2 == l)) {
			falls +=  "\n" + "password is equal to login!";
		}
	}
	if (!empty_fields && !errors && !falls) return true;
		msg =  "        Attention!            \n";
		if (empty_fields || falls) {
			empty_fields = empty_fields ? empty_fields + "\n Ч пусты ! " : "";
			msg += "The following filds are empty or filled wrong:\n"
			msg += "_________________________________________________________\n"
				+ empty_fields + empty_value + falls;
			if (errors) msg += "\n";
		}
//		msg += errors;
		alert(msg);
		return false;
}

var passComplete = false;
function comparePasswords(first, repeate){
    if(repeate.value != first.value) {
        if(document.getElementById) {
            document.getElementById("passStatus").innerHTML = "passwords mismatch...";
            document.getElementById("passStatus").style.color = "red";
            repeate.style.color = "red";
        }
        passComplete = false;
    } else {
        if(document.getElementById) {
            document.getElementById("passStatus").innerHTML = "passwords match";
            document.getElementById("passStatus").style.color = "#335533";
            repeate.style.color = "";
        }
        passComplete = true;
    }
}

function check_pass_change(f) {
    if (f.done) {
        f.done.disabled = ((f.passwd1.value == "") || !passComplete );
    }
    if (f.code) {
        var checkCodeRegex = /^\d{6}$/;
        if(!checkCodeRegex.test(f.code.value) && f.done){
            f.done.disabled = true;
        }
    }
}

FirstIntent = true;
function checkPass(f, ffirst, id) {
    var badchars = false;
    if (f.value != "") {
	badchars = checkLat(f);
    }
    if (ffirst.value != ""){
	badchars = checkLat(ffirst);
    }
    if (!badchars){
        if (f.value != "") {
            if (!FirstIntent || (f.value.length >= ffirst.value.length )) {
                FirstIntent = false;
                comparePasswords(ffirst,f);
            }
        }
    }
    if (id){
        if (badchars){
            displayStatus(id, 'badchars', ffirst.value.length);
        } else{
		if (ffirst.value.length == 0){
                    displayStatus(id, 'empty', ffirst.value.length);
                } else if (ffirst.form.login && (ffirst.value == ffirst.form.login.value)){
                    displayStatus(id, 'coincide', ffirst.value.length);
                } else if (ffirst.value.length < 4){
                    displayStatus(id, 'short', ffirst.value.length);
                } else if (ffirst.value.length > 3 && ffirst.value.length < 6){
                    displayStatus(id, 'simple', ffirst.value.length);
                } else if (ffirst.value.length > 5){
                    displayStatus(id, 'ok', ffirst.value.length);
                }
        }
    }
//    check_pass_change(f.form);
}

function checkLogin(l,id) {
	var badchars = false;
	if (l.value != "") {
		badchars = checkLat(l,1);
	}
    	if (id){
		if (badchars){
			displayStatus(id, 'badchars', l.value.length);
		} else {
			if (l.value.length == 0){
				displayStatus(id, 'empty', l.value.length);
			} else if (l.value.length < 2){
				displayStatus(id, 'short', l.value.length);
			} else if (l.value.length > 1){
                    		displayStatus(id, 'ok', l.value.length);
                	}
		}
	}
}

function displayStatus(infoId, mode, len){
    var infodiv = document.getElementById(infoId);
    if (mode == 'empty'){
        infodiv.innerHTML = '&nbsp;';
        infodiv.style.color = '';
    } else if (mode == 'short'){
        infodiv.innerHTML = "short (" + len + countSmbls(len, " symbol)", " simbol)", " simbols)") + "  form won't be sent!";
        infodiv.style.color = '#CC0000';
    } else if (mode == 'coincide'){
        infodiv.innerHTML = "the same as login (" + len + countSmbls(len, " simbol)", " simbol)") + "  form won't be sent!";
        infodiv.style.color = '#CC0000';
    } else if (mode == 'simple'){
        infodiv.innerHTML = "simple (" + len + countSmbls(len, " simbol)", " simbol)", " simbols)") + "  form won't be sent!";
        infodiv.style.color = '#498054';
    } else if (mode == 'badpasswd'){
        infodiv.innerHTML = "bad (" + len + countSmbls(len, " simbol)", " simbol)", " simbols)") + "  form won't be sent!";
        infodiv.style.color = '#CC0000';
    } else if (mode == 'badchars'){
        infodiv.innerHTML = "Check keyboard layout, form won't be sent!";
        infodiv.style.color = '#CC0000';
    } else if (mode == 'ok'){
        infodiv.innerHTML = "(" + len + countSmbls(len, " simbol)", " simbol)", " simbols)");
        infodiv.style.color = '#335533';
    }
}

function countSmbls (num, word1, word2, word5){
    if ((num >= 10) && (num <= 20)){
        return word5;
    } else if ((num % 10) == 1){
        return word1;
    } else if (((num % 10) == 2) || ((num % 10) == 3) || ((num % 10) == 4)){
        return word2;
    } else {
        return word5;
    }
}


function r(a, w)
{
    img = new Image();
    img.src = 'http://clck.yandex.ru/click/dtype=' + w + '/*' + a.href;
}

function s(a, w)
{
    img = new Image();
    img.src = 'http://clck.yandex.ru/click/dtype=' + w + '/*' + a.form.action;
    window.setTimeout(function() { a.form.submit() }, 100)
    return false;
}