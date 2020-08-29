import glob
import os
import re
from subprocess import Popen,PIPE

# == Settings ==
openttd_path = "../.."
gs_path = "../../../src/script/api/game"
# ==============

# Open output file before changing current path
f_out = open("symbols.nut", "w")

# -- Get OpenTTD version
os.chdir(openttd_path)
# If hg queues are used, the svn version is given below all patches, therefore ask for 100 log messages.
# changelog = Popen("hg log --limit 100", stdout=PIPE, shell=True).stdout.read();
# version = None

# for line in changelog.split("\n"):
# 	r = re.search("\\(svn (r[0-9]+)\\)", line)
# 	if r != None:
# 		version = r.group(1)
# 		break

version = "(TODO)"

# -- Print header in output .nut file
f_out.write("/*\n")
f_out.write(" * This file has been generated from OpenTTD source code (" + version + "),\n")
f_out.write(" * so please don't edit it manually. Instead, re-generate it using\n")
f_out.write(" * gen_api_binding.py\n")
f_out.write(" */\n")
f_out.write("g_symbols_version <- \"" + version + "\";\n")
f_out.write("g_symbols <- [\n")

# -- Scan all .sq files for the GS API in the OpenTTD source code
os.chdir(openttd_path + "/" + gs_path)
for file_name in glob.glob("*.sq"):

	class_name = None
	has_no_member = True

	for line in open(file_name, 'r'):

		# Look for class name?
		if class_name == None:
			r = re.search("DefSQClass.*\\(\"(.*)\"\\);", line)
			if r != None:
				class_name = r.group(1)

				# Open class array and give class name in first element
				# also open array for members
				f_out.write("\t[\"" + class_name + "\", [\n")

		else:
			# Member - const?
			r = re.search("DefSQConst.*\"(.*)\"\\);", line)
			has_arg_types = False
			if r == None:
				# or method?
				r = re.search("DefSQStaticMethod\\(.*\"(.*)\",.*\"\\.(.*)\"", line)
				if r != None:
					has_arg_types = True # second group contains arg types
			if r == None:
				# or advanced method?
				r = re.search("DefSQAdvancedStaticMethod.*\"(.*)\"\\);", line)
			if r != None:
				member_name = r.group(1)
				if has_arg_types:
					arg_types = "\"" + r.group(2) + "\""
				else:
					arg_types = "null"

				# ignore some magic methods:
				if member_name == "import":
					continue

				f_out.write("\t\t[\"" + member_name + "\", " + class_name + "." + member_name + ", " + arg_types + "],\n")
				has_no_member = False

			# End of class?
			if re.search("^}$", line.strip()) != None:

				if has_no_member:
					f_out.write("\t\t[\"\", " + class_name + "],\n")


				f_out.write("\t]],\n") # terminate member list + class info

				# Allow finding additional classes in the same file
				class_name = None


	# End of .sq file


# end of symbols => close table
f_out.write("];\n")


# -- Close output file
f_out.close()

print("symbols.nut has been re-generated based on OpenTTD " + version)
