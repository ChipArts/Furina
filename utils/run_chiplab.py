#! /usr/bin/env python3
import os

# 获取CHIPLAB_HOME环境变量
chiplab_home = os.getenv("CHIPLAB_HOME")

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

# 清空CHIPLAB_HOME/IP/myCPU
os.system("rm -rf %s/IP/myCPU/*" % chiplab_home)

# 拷贝所有文件到CHIPLAB_HOME/IP/myCPU目录下
for f in files:
	os.system("cp %s %s/IP/myCPU" % (f, chiplab_home))
	# print("Copy %s to %s/IP/myCPU" % (f, chiplab_home))

# 将chiplab_top.sv改名为core_top.sv
os.system("mv %s/IP/myCPU/chiplab_top.sv %s/IP/myCPU/core_top.sv" % (chiplab_home, chiplab_home))

# 定义要仿真的项目
"""
可选的项目有：
func/func_lab3  func/func_lab4 
func/func_lab6  func/func_lab7  func/func_lab8  func/func_lab9 
func/func_lab14 func/func_lab15 func/func_lab19 func/func_advance

fireye/A0 fireye/B2 fireye/C0 fireye/D1 fireye/I2
my_program memset dhrystone coremark linux rtthread
c_prg/memcmp c_prg/inner_product c_prg/lookup_table
c_prg/loop_induction c_prg/minmax_sequence c_prg/product_sequence
"""
prog = "func/func_advance"

# 进入CHIPLAB_HOME/sims/verilator/run_prog目录
os.chdir("%s/sims/verilator/run_prog" % chiplab_home)

# 执行chiplab命令
# os.system(f"./configure.sh --run {prog} --tail-waveform --waveform-tail-size 10000 --tail-simu-trace --trace-tail-size 10000")
os.system(f"./configure.sh --run {prog} --threads 8")
os.system("make clean")
os.system("make -j16")

# # 进入CHIPLAB_HOME/sims/verilator/run_prog/log/{prog}目录
# os.chdir("%s/sims/verilator/run_prog/log/%s" % (chiplab_home, prog))

# # 打开波形
# os.system("gtkwave simu_trace.fst")
