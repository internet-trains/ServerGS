
/**
 * Based on OpenTTD version, this method returns the name of the symbols
 * file to load. It will pick the "best" but compatible symbols file.
 */
function GetSymbolsFileName()
{
	local openttd_version = Helper.GetOpenTTDVersion();
	local ver14 = (openttd_version.Major == 1 && openttd_version.Minor >= 4) || (openttd_version.Major > 1);
	if (ver14 && openttd_version.Revision >= 25808) { // >1.4 && rev > 25808
		return "symbols.nut";
	} else {
		return "symbols-1.3.2.nut";
	}
}
