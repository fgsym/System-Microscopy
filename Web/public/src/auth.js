function showDiv(d)
{
	var boxdiv = document.getElementById(d);
	if (boxdiv != null) {
		if (boxdiv.style.display!='block') {
			boxdiv.style.display='block';
		} else
			boxdiv.style.display='none';
			return false;
		}
}
function hideDiv(d)
{
	var boxdiv = document.getElementById(d);
	boxdiv.style.display = 'none';
	return false;
}
function showLogin(islogin, rp)
{
	var f = document.forms['loginform'];
	if (document.getElementById && f) {
		if (typeof(rp) != 'undefined') {
			f.retpath.value = rp;
		}
		if (islogin == 2) {
			var login = getCookie('author');
			islogin = (login && login.length > 1);
			if (islogin) {
				if (f.login.value != login) {
					f.login.value = login;
					f.passwd.value = '';
				}
			}
		}
		document.getElementById('login-form').style.display = 'block';
		islogin ? f.passwd.focus() : f.login.focus();
		return false;
	}
	var img = new Image();
	img.src = '';
	return true;
}
function hideLogin()
{
	document.getElementById('login-form').style.display = 'none';
	return false;
}


function settime()
{
	document.forms['loginform'].timestamp.value = new Date().getTime();
}
