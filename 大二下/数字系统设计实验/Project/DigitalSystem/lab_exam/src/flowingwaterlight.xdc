set_property PACKAGE_PIN A14 [get_ports clk]
set_property PACKAGE_PIN A16 [get_ports direction]
set_property PACKAGE_PIN A18 [get_ports reset]
create_clock -period 10.000 -name clk -waveform {0.000 5.000} [get_ports clk]
