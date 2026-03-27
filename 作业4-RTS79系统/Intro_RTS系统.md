# 作业4-IEEE RTS 79系统

## 1 Reliability Test System

| 版本名称 | 发布年份 | 核心变化与特征 |
| :--- | :--- | :--- |
| **RTS-79** | 1979 | 第一个标准可靠性测试系统，单区域 24 节点，定义了基本的 MTTF/MTTR 数据。 |
| **RTS-96** | 1996 | **重大扩展**。将三个 RTS-79 系统互联，形成 73 节点三区域系统，用于研究多区域可靠性。 |
| **RTS-GMLC** | **2019** | **现代化更新**。引入高比例风电/光伏、电池储能及地理空间一致性的时序预测数据。 |

### IEEE-RTS 24-Bus

MATPOWER 的 case24_ieee_rts 主要针对潮流计算和最优潮流（OPF）计算，因此仅包含发电机组、负荷、线路阻抗、成本函数等参数，缺少停运率（FOR）、平均故障时间（MTTF）和平均修复时间（MTTR）等可靠性参数.

### RBTS

**Roy Billinton Test System (RBTS)** 是一套专门为电力系统可靠性教学和研究而设计的标准测试系统. 在电力系统可靠性评估领域，虽然 1979 年发布的 **IEEE-RTS** 被广泛使用，但它对于初学者来说规模偏大且过于复杂，往往需要依赖复杂的计算机程序才能得出结果 。为了让学生能通过**手工计算**深刻理解可靠性建模、假设和计算过程，萨斯喀彻温大学（University of Saskatchewan）的 Roy Billinton 教授团队在1989年发布了这套更为精简的 RBTS 系统 。

其基本结构如下：

- 包含6条母线（Buses）、9条传输线
- 共有11台发电机组，总装机容量为240MW
- 系统峰值负荷为185MW
- 输电系统电压为230kV

BTS 被进一步扩展到了**配电系统**层面，以便教学如何评估从变电站到最终用户端的可靠性 。设计者挑选了 RBTS 中的两个负荷节点进行详细设计 （1991年）：

- BUS 2：与发电机组相连
- BUS 4：没有直接相连的电源，依靠输电系统供电

RBTS配电网设计原则

- 运行模式：闭环设计，放射状运行，通过常开联络点（Normally Open sectionalising points）
- 故障恢复：当馈线发生故障时，可以通过环网单元（Ring main units）移动分段点，从备用供电点恢复供电
- 设备细节：BUS 4由于负荷较大（40MW），采用了更高可靠性的 **33kV 环网**和三个供应点（SP1, SP2, SP3） ，**BUS 2**：负荷较小（20MW），仅采用单一供应点 ；**用户类型**：涵盖了住宅、小用户、政府/机构、商业和办公室等多种类型 。

配电网可靠性的关键研究

架空线 VS. 地缆，架空线的故障率通常更高，电缆系统平均停工时间更长；

设备配置：是否安装分段开关、支路熔断器、备用电源

RBTS配电网补充，Billinton 教授团队随后在其他论文中补充了 **BUS 3**、**BUS 5** 和 **BUS 6** 的配电网模型（1996年）

**论文题目**：*A Test System For Teaching Overall Power System Reliability Assessment* (1996)

- **BUS 3、5、6**：这些节点的配电网结构主要用于评估分布式电源（DG）、微电网以及不同接线方式对可靠性的影响。
- **BUS 1**：作为系统的平衡节点（Slack Bus）和主要发电中心，在标准教学模型中通常不单独为其设计复杂的配电网。

## 2 算例数据获取

### IEEE 可靠性测试系统 (RTS/RBTS) 演进与对比

| 系统名称 | 发布时间 | 原文引用 | 算例链接 | 系统特点 |
| :--- | :--- | :--- | :--- | :--- |
| **RTS-79** | 1979年 | IEEE RTS Task Force, "IEEE Reliability Test System," *IEEE Trans. PAS*, 1979. | [PSTCA Archive](https://labs.ece.uw.edu/pstca/rts/rts79/ieeerts79.txt) | 经典的 24 节点单区域系统，首次定义了机组停运（MTTF/MTTR）和负荷时序的标准数据。 |
| **RTS-GMLC** | 2019年 | Barrows, C., et al., "The IEEE Reliability Test System: A Proposed 2019 Update," *IEEE Trans. Power Syst.*, 2019. | [GitHub Repo](https://github.com/GridMod/RTS-GMLC) | 现代化更新版本，引入高比例新能源、电池储能、真实地理坐标及高分辨率（5min）时序数据。 |
| **RBTS** | 1989年 | R. Billinton, et al., "A Reliability Test System for Educational Purposes-Basic Data," *IEEE Trans. Power Syst.*, 1989. | [PSTCA Archive](https://labs.ece.uw.edu/pstca/rbts/rbts.txt) | 6 节点小型系统，专为教学设计，结构简单且参数完整，涵盖了从发电到配电的可靠性指标。 |


由于 RBTS 规模很小（仅 6 个节点，11 台发电机组），学术界通常直接从论文表格中提取数据。

原始论文（最推荐）：搜索题目 "A Reliability Test System for Educational Purposes-Basic Data"。文中 Table II 给出了所有发电机组的 MTTF（平均故障时间）和 MTTR（平均修复时间），Table III 给出了输电线路的故障率和修复时间