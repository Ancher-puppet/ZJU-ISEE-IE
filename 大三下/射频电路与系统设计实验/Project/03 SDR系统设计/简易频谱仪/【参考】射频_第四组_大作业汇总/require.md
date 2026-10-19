<!--
 * @Author: Ancher-puppet 2170351721@qq.com
 * @Date: 2026-06-01 00:14:11
 * @LastEditors: Ancher-puppet 2170351721@qq.com
 * @LastEditTime: 2026-06-01 00:14:24
 * @FilePath: \射频_第四组_大作业汇总\require.md
 * @Description: 这是默认设置,请设置`customMade`, 打开koroFileHeader查看配置 进行设置: https://github.com/OBKoro1/koro1FileHeader/wiki/%E9%85%8D%E7%BD%AE
-->
频谱分析仪是研究电信号频谱结构的仪器，利用软件无线电平台（HackRF，USRP），实现一个简易频谱仪。支持频谱显示、频谱扫描、峰值捕获等功能。其原理框图如下：

基本要求：
1、全程测试频率范围：300MHz到 3 GHz 							（10分）
2、分辨率带宽（RBW）：100Hz、300Hz、1KHz、3KHz、10KHz、30KHz、100KHz、300KHz、1 MHz、3MHz、10MHz可选													（15分）
3、动态范围：RBW=100Hz时，大于60dB;RBW=10MHz时，大于30dB		（15分）
4、测试幅度误差：小于1dB										（10分）
5、测试频率误差：在不同RBW设置测试时，小于相对应RBW的1%		（10分）

扩展要求：
1、全程测试频率扩展范围：70MHz到6GHz									（5分）

2、AM、FM、ASK、FSK、BPSK调制识别							（20分）
载波频率：433MHz       调制信号：语音信号

3、AM调制信号的调制度、交调失真测量							（15分）
载波频率：433MHz       调制信号：单音信号