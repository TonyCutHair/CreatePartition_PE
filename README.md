# CreatePartition_PE
a simple powershell script to create partitions in WinPE

使用情景: 三个可选变量, 强制定义-win.
1. 不指定Win分区					CreatePartitions.exe -Win 0
2. 指定Win分区百分比, 			CreatePartitions.exe -Win 30   -->占用剩余空间(除去EFI,MSR,和HP_RECOVERY)的百分比, 不是全盘比例.
3. Win和Data均分3分				CreatePartitions.exe -Win 0 -Windata 2 -Recovery xx			-->此处Windata为1~10之间.
4. 指定Win分区,剩余Data			CreatePartitions.exe -Win 100 -Recovery xx		-->此处Windata必须为 1.
5. 指定Win分区,其余均分				CreatePartitions.exe -Win 100 -Windata 2 -Recovery xx		-->此处Windata为 2~10之间.
6. 指定Win分区,Data分区大小			CreatePartitions.exe -Win 100 -Windata 200 -Recovery xx		--> 分3个区,win,data,rest of disk.
