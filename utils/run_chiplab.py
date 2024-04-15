
import os

# 获取CHIPLAB_HOME环境变量
chiplab_home = os.getenv("CHIPLAB_HOME")

# 获取当前目录下所有的[".v", ".h", ".vh", ".sv", ".svh", ".vhdl"]文件
files = os.listdir(os.getcwd())
files = [f for f in files if f.endswith(".v") or f.endswith(".h") or f.endswith(".vh") or f.endswith(".sv") or f.endswith(".svh") or f.endswith(".vhdl")]

# 检查文件的重名问题
for f in files:
	if files.count(f) > 1:
		print("Error: file %s is duplicated!" % f)
		exit(1)

# 拷贝所有文件到CHIPLAB_HOME/IP/myCPU目录下
for f in files:
	os.system("cp %s %s/IP/myCPU" % (f, chiplab_home))
	# print("Copy %s to %s/IP/myCPU" % (f, chiplab_home))

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
prog = "func/func_lab3"

# 进入CHIPLAB_HOME/sims/verilator/run_prog目录
os.chdir("%s/sims/verilator/run_prog" % chiplab_home)

# 修改Makefile_run
with open("Makefile_run", "w") as f:
	f.write(
"""
DUMP_DELAY=0
DUMP_WAVEFORM=1
TIME_LIMIT=0
BUS_DELAY=y
BUS_DELAY_RANDOM_SEED=5570815 
END_PC=1c000010
SAVE_BP_TIME=0
RAM_SAVE_BP_FILE=#pwd#
TOP_SAVE_BP_FILE=
RESTORE_BP_TIME=0
RAM_RESTORE_BP_FILE=
TOP_RESTORE_BP_FILE=

ifeq ('${BUS_DELAY}', 'y')
RUN_FLAG += --simu-bus-delay
RUN_FLAG += --simu-bus-delay-random-seed $(BUS_DELAY_RANDOM_SEED)
endif

golden_trace_make:
	python3 ./qemu_log_helper.py --asm test.s --log single.log --dump-rftrace golden_trace.txt 
simulation_run_prog:
	../output ${RUN_FLAG} --dump-delay $(DUMP_DELAY) --dump-waveform $(DUMP_WAVEFORM) --time-limit $(TIME_LIMIT) --save-bp-time $(SAVE_BP_TIME) --ram-save-bp-file $(RAM_SAVE_BP_FILE) --top-save-bp-file $(TOP_SAVE_BP_FILE) --restore-bp-time $(RESTORE_BP_TIME) --ram-restore-bp-file $(RAM_RESTORE_BP_FILE) --top-restore-bp-file $(TOP_RESTORE_BP_FILE) --end-pc $(END_PC) 


""")

# 执行chiplab命令
os.system(f"./configure.sh --run {prog} --tail-waveform --waveform-tail-size 2000 --tail-simu-trace --trace-tail-size 2000")
os.system("make -j16")

# 进入CHIPLAB_HOME/sims/verilator/run_prog/log/{prog}目录
os.chdir("%s/sims/verilator/run_prog/log/%s" % (chiplab_home, prog))

# 打开波形
os.system("gtkwave simu_trace.fst")
