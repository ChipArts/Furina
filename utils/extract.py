# windows 环境

import os

# 获取chip_home环境变量
chip_home = "..\\"

# 清空chip_home\\myCPU
os.system("del /q %s\\myCPU\\*" % chip_home)

# 获取当前目录及子目录下所有的[".v", ".h", ".vh", ".sv", ".svh", ".vhdl"]文件
files = []
for root, dirs, fs in os.walk(".."):
	for f in fs:
		files.append(os.path.join(root, f))
files = [f for f in files if f.endswith(".v") or f.endswith(".h") or f.endswith(".vh") or f.endswith(".sv") or f.endswith(".svh") or f.endswith(".vhdl")]
print(files)

# 检查文件的重名问题
for f in files:
	if files.count(f) > 1:
		print("Error: file %s is duplicated!" % f)
		exit(1)

# 检查chip_home\\myCPU是否存在，不存在则创建
if not os.path.exists("%s\\myCPU" % chip_home):
	os.system("mkdir %s\\myCPU" % chip_home)





# 拷贝所有文件到chip_home\\myCPU目录下
for f in files:
	os.system("copy %s %s\\myCPU" % (f, chip_home))
