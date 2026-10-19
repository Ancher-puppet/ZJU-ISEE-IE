classdef finalwork < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure            matlab.ui.Figure
        Panel_2             matlab.ui.container.Panel
        IMDEditField        matlab.ui.control.EditField
        IMDEditFieldLabel   matlab.ui.control.Label
        mEditField          matlab.ui.control.EditField
        mEditFieldLabel     matlab.ui.control.Label
        spec_sweep_2        matlab.ui.control.StateButton
        Switch_2            matlab.ui.control.ToggleSwitch
        Label_24            matlab.ui.control.Label
        Label_23            matlab.ui.control.Label
        CognBelief          matlab.ui.control.NumericEditField
        Label_22            matlab.ui.control.Label
        State               matlab.ui.control.EditField
        Label_20            matlab.ui.control.Label
        CognMod             matlab.ui.control.EditField
        Label_19            matlab.ui.control.Label
        Switch              matlab.ui.control.ToggleSwitch
        Label_15            matlab.ui.control.Label
        ListBox             matlab.ui.control.ListBox
        Label_14            matlab.ui.control.Label
        Panel               matlab.ui.container.Panel
        Button_3            matlab.ui.control.Button
        Gain_2              matlab.ui.control.Knob
        Label_25            matlab.ui.control.Label
        Lamp_2              matlab.ui.control.Lamp
        Label_21            matlab.ui.control.Label
        Label_13            matlab.ui.control.Label
        EditField_5         matlab.ui.control.NumericEditField
        Label_12            matlab.ui.control.Label
        Gauge               matlab.ui.control.LinearGauge
        Label_11            matlab.ui.control.Label
        MhzLabel_5          matlab.ui.control.Label
        MhzLabel_4          matlab.ui.control.Label
        MhzLabel_3          matlab.ui.control.Label
        EditField_4         matlab.ui.control.NumericEditField
        Label_9             matlab.ui.control.Label
        EditField_3         matlab.ui.control.NumericEditField
        EditField_3Label    matlab.ui.control.Label
        EditField_2         matlab.ui.control.NumericEditField
        Label_8             matlab.ui.control.Label
        spec_sweep          matlab.ui.control.StateButton
        UIAxes              matlab.ui.control.UIAxes
        Panel_3             matlab.ui.container.Panel
        Button_2            matlab.ui.control.Button
        RBWDropDownLabel_2  matlab.ui.control.Label
        DropDown_2          matlab.ui.control.DropDown
        Gain                matlab.ui.control.Knob
        Label_6             matlab.ui.control.Label
        MHzLabel            matlab.ui.control.Label
        RBWDropDown         matlab.ui.control.DropDown
        RBWDropDownLabel    matlab.ui.control.Label
        Input_1             matlab.ui.control.NumericEditField
        Label_3             matlab.ui.control.Label
        Lamp_3              matlab.ui.control.Lamp
        Label_7             matlab.ui.control.Label
        Button              matlab.ui.control.Button
    end

    
    properties (Access = private)
        finish = 0; % Description
        transmit_pluto=0;
    end


    % Callbacks that handle component events
    methods (Access = private)

        % Button pushed function: Button
        function Button_Start(app, event)
%% 频谱分析仪
            %% 设置参数输入
            %RBW
            select_RBW = app.RBWDropDown.Value;
            switch select_RBW
                case '300KHz'
                    RBW = 300e3;
                case '100KHz'
                    RBW = 100e3;
                case '30KHz'
                    RBW=30e3;
                case '10KHz'
                    RBW=10e3;
                case '3KHz'
                    RBW=3e3;
                case '1KHz'
                    RBW=1e3; 
                case '300Hz'
                    RBW=300;
                case '100Hz'
                    RBW=100;
                case '1MHz'
                    RBW=1e6;
                case '3MHz'
                    RBW=3e6;
                case '10MHz'
                    RBW=1e7;
            end

            %分析带宽
            select_bth = app.DropDown_2.Value;
            switch select_bth
                case '50MHz'
                    input_span = 50e6;
                case '20MHz'
                    input_span = 20e6;
                case '10MHz'
                    input_span = 10e6;
                case '5MHz'
                    input_span = 5e6;
                case '1MHz'
                    input_span = 1e6;
            end

            % 校验
            if input_span / RBW < 2
                if RBW >= 1e6
                    r_str = sprintf('%.1fMHz', RBW/1e6);
                elseif RBW >= 1e3
                    r_str = sprintf('%.1fKHz', RBW/1e3);
                else
                    r_str = sprintf('%.0fHz', RBW);
                end
                uialert(app.UIFigure, ...
                    sprintf('Span(%.1fMHz)必须至少是RBW(%s)的2倍!\n请增大分析带宽或减小RBW。', ...
                    input_span/1e6, r_str), ...
                    '参数错误', 'Icon', 'error');
                return;
            end
            master_rate=50e6;

            %% 创建频谱分析仪
            scope = spectrumAnalyzer;
            scope.FrequencyResolutionMethod = 'RBW';
            scope.Method = 'Welch';
            scope.Name = '频谱分析仪';
            scope.Window = 'Hann';
            scope.FrequencySpan = 'Span and center frequency';
            
            % 将频谱分析仪的采样率设置为与RWB匹配
            scope.SampleRate = master_rate;
            scope.RBWSource='Property';
            scope.RBW = RBW;
            scope.Span=input_span;

            % 设置接收机
            center_freq = app.Input_1.Value * 1e6; 
            input_gain = app.Gain.Value;
            rxRadio = sdrrx(...
              'Pluto', ...
              'RadioID', 'usb:0', ...
              'CenterFrequency',center_freq, ...
              'BasebandSampleRate',master_rate / 1, ...
              'Gain',round(input_gain),...
              'OutputDataType', 'single',...
              'SamplesPerFrame',4096);

            while (app.finish==0)
                app.Lamp_3.Color = 'g';
                x = rxRadio();%接受数据帧
                scope(x);
                pause(0.01);
            end
            
            %% 释放频谱分析仪、接收机
            release(scope);
            release(rxRadio);

            %重置finish为0，表示此时可以点击开始
            app.finish = 0;
            %关闭频谱分析仪，指示灯调整为红色
            app.Lamp_3.Color = 'r';
            
        end

        % Button pushed function: Button_2, Button_3
        function Button_Stop(app, event)
%% 设置结束按钮
            app.finish = 1;%按下结束按钮后，将app.finish置为1
        end

        % Value changed function: spec_sweep
        function Spec_sweep(app, event)
%% 频谱扫描仪器
            %% 参数设置：
            start_freq = app.EditField_2.Value*1e6;%起始频率
            stop_freq = app.EditField_3.Value*1e6;%截止频率
            usrp_fs = app.EditField_4.Value*1e6;%采样率
            usrp_gain = app.Gain.Value;%增益，从面板旋钮读取
            usrp_dec=1;%抽取因子
            usrp_masterclockrate=usrp_dec*usrp_fs;%AD时钟频率

            %将数据清零
            app.Gauge.Value = 0;
            app.EditField_5.Value = 0;

            % 参数
            nfrmhold            = 20;           % 设置每次重新调整USRP时要接受的帧数
            nfft                = 4096;  % FFT点数自适应：最小4096，RBW≈100Hz级别
            dec_factor          = 16;           % 控制在绘制完整扫描结果之前执行的抽取级别
            overlap             = 0.5;          % 重叠百分比，0.5意味着步进采样率一半
            nfrmdump            = 100;          % 重新调整后要转储的帧数
            % 窗函数（Hann窗，和面板1一致，减频谱泄漏）
            win_vec             = hann(4096, 'periodic');

            % 根据输入的信息计算所需要的步进次数
            usrp_tunerfreq  = start_freq:usrp_fs*overlap:stop_freq;     %调谐器频率范围，单位HZ
            if( max(usrp_tunerfreq) < stop_freq )                         % 检查整个频率范围是否被覆盖，否则添加一个额外的调谐器频率
                usrp_tunerfreq(length(usrp_tunerfreq)+1) = max(usrp_tunerfreq)+usrp_fs*overlap;
            end
            nretunes = length(usrp_tunerfreq);                            %计算所需要的重调次数
           
            %% 配置接收机
            rxRadio = sdrrx(...
              'Pluto', ...
              'RadioID', 'usb:0', ...
              'CenterFrequency',usrp_tunerfreq(1), ...
              'BasebandSampleRate',usrp_masterclockrate / usrp_dec, ...
              'Gain',round(usrp_gain),...
              'OutputDataType', 'single',...
              'SamplesPerFrame',4096);

             % FIR 抽取器
             obj_decmtr = dsp.FIRDecimator(...
                 'DecimationFactor',     dec_factor,...
                 'Numerator',            fir1(300,1/dec_factor));

             %% 计算
             %usrpsdr_data_fft维度为【1*4096】
             %fft_reorder维度为【20*2048】
             %fft_dec维度为【步进次数*128】
             usrpsdr_data_fft = zeros(1,nfft);                     % 一帧数据4096，保存得到的fft结果
             %数组维度为nfrmhold，即每次调整中心频率后要接受的帧数，长度为重叠长度
             fft_reorder = zeros(nfrmhold,nfft*overlap);  % 具有重叠补偿的矩阵以保持重新排序的ffts [navg x nfft*overlap]
             fft_dec = zeros(nretunes,nfft*overlap/dec_factor);   % 具有重叠补偿的矩阵以保存所有的fftsffts  [ntune x nfft*overlap/data_decimate]
             
             % 创建进度变量
             tune_progress = 0;
             
             % 开始计时
             tic;
             %提示灯显示为绿色
             app.Lamp_2.Color = 'g';
             
             %% 扫描
             for ntune = 1:1:nretunes
                 % 将USRP调整到新的中心频率
                 rxRadio.CenterFrequency = usrp_tunerfreq(ntune);
                 pause(0.01);

                 % 支持中断
                 if app.finish
                     app.Lamp_2.Color = 'r';
                     app.Gauge.Value = 0;              % 进度归零
                     app.EditField_5.Value = 0;        % 计时归零
                     app.finish = 0;                   % 清除标志，允许下次扫描
                     app.spec_sweep.Value = false;     % 按钮弹起
                     release(rxRadio);
                     return;
                 end

                 % 转储帧以清除软件缓冲区，避免数据影响平均值
                 for frm = 1:1:nfrmdump
                     % 从usrp获取一帧，这里的数据是舍弃的
                     usrpsdr_data = step(rxRadio);
                 end

                 % 每一个中心频率处循环接受nfrmhold帧，计算平均
                 for frm = 1:1:nfrmhold

                     % 从USRP上获取一帧
                     usrpsdr_data = step(rxRadio);

                     % 去除直流分量
                     usrpsdr_data = usrpsdr_data - mean(usrpsdr_data);
                     %加Hann窗后FFT
                     usrpsdr_data_fft = abs(fft(usrpsdr_data .* win_vec, nfft))';

                     % 重新排列 fft
                     fft_reorder(frm,( 1 : (overlap*nfft/2) ))      = usrpsdr_data_fft( (overlap*nfft/2)+(nfft/2)+1 : end );   % -ve
                     fft_reorder(frm,( (overlap*nfft/2)+1 : end ))  = usrpsdr_data_fft( 1 : (overlap*nfft/2) );                % +ve

                 end
                 

                 % 求功率平均值
                 fft_reorder_proc = mean(fft_reorder);

                 % 抽取数据以平滑并存储在频谱矩阵中
                 fft_dec(ntune,:) = step(obj_decmtr,fft_reorder_proc')';
                 %扫描进度
                 tune_progress = floor(ntune*100/nretunes);
                 app.Gauge.Value = tune_progress;
             end
             
             %提示灯显示为红色
             app.Lamp_2.Color = 'r';
             fft_masterreshape = reshape(fft_dec',1,ntune*nfft*overlap/dec_factor);
             %计算功率谱
             y_data_dbm = 10*log10(fft_masterreshape.^2);
             %创建X轴
             freq_bin_width = (usrp_fs/nfft);       
             freq_axis = (usrp_tunerfreq(1)-usrp_fs/2*overlap  :  freq_bin_width*dec_factor  :  (usrp_tunerfreq(end)+usrp_fs/2*overlap)-freq_bin_width)/1e6;

             %扫频结果
             plot(app.UIAxes,freq_axis,y_data_dbm,'linewidth',1.25);
             %扫描时间
             app.EditField_5.Value = toc;
             release(rxRadio);
        end

        % Value changed function: Switch
        function SwitchValueChanged(app, event)
%% 模式识别
            event = app.Switch.Value;
            start_on = "On";
            if(strcmp(event,start_on))
                %加载神经网络
                load trainedModulationClassificationNetwork trainedNet_mine

                mode_type = app.ListBox.Value;
                sps = 8;
                spf = 1024;
                fs = 200e3;

                %根据调制模式得到数据源
                dataSrc = ModClassGetSource(mode_type, sps, 2*spf, fs);
                %据类型返回调制器函数句柄MOD
                modulator = ModClassGetModulator(mode_type, sps, fs);
                x = dataSrc();
                y = modulator(x);%y为根据所选择的调制模式调制后得到的数据


                center_freq_pluto = 433e6;
                %% 发射机设置
                txRadio = sdrtx('Pluto');
                txRadio.RadioID = 'usb:0';
                txRadio.CenterFrequency = center_freq_pluto;%中心频率
                txRadio.BasebandSampleRate = fs;%采样速率
                txRadio.Gain = -5;
                %% 接收机设置
               rxRadio = sdrrx(...
                    'Pluto', ...
                    'RadioID', 'usb:0', ...
                    'CenterFrequency',center_freq_pluto, ...
                    'BasebandSampleRate',5e6 / 25, ...
                    'Gain',10,...
                    'OutputDataType', 'single',...
                    'SamplesPerFrame', 1024,...
                    'EnableBurstMode', true,...
                    'NumFramesInBurst',1);
                % 发射数据
                %移除滤波器瞬变
                app.State.Value = '发射机开始发送数据';
                y = y(4*sps+1:end,1);
                maxVal = max(max(abs(real(y))), max(abs(imag(y))));
                y = y *0.8/maxVal;
                %将波形信号下载到收音机，并通过无线反复传输
                if(app.transmit_pluto)
                    transmitRepeat(txRadio, complex(y));
                    %app.mEditField.Value=1;
                else
                    %app.mEditField.Value=0;
                end

                pause(0.05);

                %% 接收数据
                app.State.Value = '正在识别接收信号';
                % 清除缓存数据，避免影响
                for frm = 1:1:20
                    % 从sdr获取一帧
                    rx = rxRadio();
                end

                rx = rxRadio();
                framePower = mean(abs(rx).^2);%mean(A)返回包含每列均值的行向量
                rx = rx / sqrt(framePower);%sqrt(X)返回数组X的每个元素的平方根
                reshapedRx(1,:,1,1) = real(rx);
                reshapedRx(1,:,2,1) = imag(rx);
                [predic_mod,percent] = classify(trainedNet_mine,reshapedRx);

                app.CognMod.Value = char(predic_mod);
                app.CognBelief.Value = double(max(percent)*100);
                app.State.Value = '识别完成';
                release(rxRadio);
                release(txRadio);

            else
                app.State.Value = '请选择调制模式后按下开关';
            end
        end

        % Value changed function: Switch_2
        function Switch_2ValueChanged(app, event)
            value = app.Switch_2.Value;
            if(strcmp(value,'On'))
                app.transmit_pluto = 1;
                app.State.Value = '发射机已开启，等待模式识别开关';
            else
                app.transmit_pluto = 0;
                app.State.Value = '发射机已关闭';
            end

        end

        % Value changed function: spec_sweep_2
        function AM_modualte(app, event)
%% AM调制度 & 交调失真测量
            fm = 1e3;          % 单音调制信号频率 1kHz
            fc = 433e6;        % 载波频率
            fs = 200e3;        % 基带采样率
            spf = 8192;        % 每帧采样数（更多点→更高频率分辨率）
            m_target = 0.5;    % 目标调制度

            %% 1. 生成AM基带信号
            % AM: s(t) = [1 + m*cos(2πfm t)], 纯实基带
            t = (0:spf-1)' / fs;
            msg = cos(2*pi*fm*t);
            am_baseband = 1 + m_target * msg;
            am_baseband = am_baseband / max(abs(am_baseband)) * 0.8;

            %% 2. Pluto TX 发射
            app.State.Value = '发射AM单音信号...';
            txRadio = sdrtx('Pluto');
            txRadio.RadioID = 'usb:0';
            txRadio.CenterFrequency = fc;
            txRadio.BasebandSampleRate = fs;
            txRadio.Gain = -5;
            transmitRepeat(txRadio, complex(am_baseband));

            %% 3. Pluto RX 接收
            pause(0.1);
            rxRadio = sdrrx('Pluto', ...
                'RadioID', 'usb:0', ...
                'CenterFrequency', fc, ...
                'BasebandSampleRate', fs, ...
                'Gain', 10, ...
                'OutputDataType', 'single', ...
                'SamplesPerFrame', spf);

            % 清除缓冲区
            for k = 1:10
                rxRadio();
            end
            rx_data = rxRadio();  % 取一帧分析

            release(rxRadio);
            release(txRadio);

            %% 4. FFT频谱分析
            rx_data = rx_data - mean(rx_data);              % 去直流偏置
            win = hann(spf, 'periodic');
            Y = fft(rx_data .* win);
            Y_mag = abs(fftshift(Y))';                     % 移到零频居中
            Y_dB = 20*log10(Y_mag + eps);                  % dB单位
            freq_axis = (-spf/2 : spf/2-1)' * fs / spf;    % 基带频率轴

            %% 5. 找载波峰和边带峰
            Y_abs = Y_mag;
            [pks, locs] = findpeaks(Y_abs, 'SortStr', 'descend', 'MinPeakDistance', 10);

            if length(locs) >= 3
                % 载波 = 最高峰(应在0Hz附近)
                [~, idx_sort] = sort(abs(freq_axis(locs)));  % 按频率绝对值排序
                idx_carrier = locs(idx_sort(1));             % 最接近0Hz的峰=载波
                V_carrier = Y_abs(idx_carrier);
                f_peaks = freq_axis(locs);

                % 找±fm的边带 (理论值 ±1kHz)
                sideband_idx = [];
                sideband_vals = [];
                for i = 1:length(locs)
                    if locs(i) ~= idx_carrier && abs(abs(freq_axis(locs(i))) - fm) < 500
                        sideband_idx(end+1) = locs(i);
                        sideband_vals(end+1) = Y_abs(locs(i));
                    end
                end

                if ~isempty(sideband_vals)
                    % 调制度 m = 2 * mean(V_sideband) / V_carrier
                    m_measured = 2 * mean(sideband_vals) / V_carrier;

                    % 交调失真: 找±fm以外的其他峰相对于边带的功率比
                    imd_peaks = [];
                    for i = 1:length(locs)
                        if locs(i) ~= idx_carrier && ~ismember(locs(i), sideband_idx)
                            if abs(freq_axis(locs(i))) > 0  % 排除DC
                                imd_peaks(end+1) = Y_dB(locs(i));
                            end
                        end
                    end

                    if ~isempty(imd_peaks) && ~isempty(sideband_vals)
                        sideband_dB = 20*log10(mean(sideband_vals));
                        imd_dB = max(imd_peaks) - sideband_dB;  % 最差交调(dBc)
                    else
                        imd_dB = -inf;
                    end

                    % 显示结果
                    app.mEditField.Value = round(m_measured * 100) / 100;
                    app.MDEditField.Value = round(max(imd_dB, -60) * 10) / 10;
                    app.State.Value = sprintf('测量完成 m=%.2f IMD=%.1fdBc', m_measured, imd_dB);
                else
                    app.State.Value = '未检测到边带，检查TX/RX连接';
                end
            else
                app.State.Value = '未检测到足够峰值，检查信号';
            end 
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create UIFigure and hide until all components are created
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [100 100 1371 581];
            app.UIFigure.Name = 'MATLAB App';

            % Create Panel_3
            app.Panel_3 = uipanel(app.UIFigure);
            app.Panel_3.TitlePosition = 'centertop';
            app.Panel_3.Title = '频谱分析';
            app.Panel_3.BackgroundColor = [0.9412 0.9412 0.9412];
            app.Panel_3.FontWeight = 'bold';
            app.Panel_3.FontSize = 16;
            app.Panel_3.Position = [0 -3 266 585];

            % Create Button
            app.Button = uibutton(app.Panel_3, 'push');
            app.Button.ButtonPushedFcn = createCallbackFcn(app, @Button_Start, true);
            app.Button.BackgroundColor = [0 0 1];
            app.Button.FontSize = 14;
            app.Button.FontWeight = 'bold';
            app.Button.FontColor = [1 1 1];
            app.Button.Position = [80 227 100 28];
            app.Button.Text = '开始频谱分析';

            % Create Label_7
            app.Label_7 = uilabel(app.Panel_3);
            app.Label_7.HorizontalAlignment = 'right';
            app.Label_7.Position = [46 521 201 22];
            app.Label_7.Text = '绿灯：运行中；红灯：结束/等待运行';

            % Create Lamp_3
            app.Lamp_3 = uilamp(app.Panel_3);
            app.Lamp_3.Position = [19 523 18 18];
            app.Lamp_3.Color = [1 0 0];

            % Create Label_3
            app.Label_3 = uilabel(app.Panel_3);
            app.Label_3.HorizontalAlignment = 'right';
            app.Label_3.Position = [21 449 77 24];
            app.Label_3.Text = '输入中心频率';

            % Create Input_1
            app.Input_1 = uieditfield(app.Panel_3, 'numeric');
            app.Input_1.Position = [136 450 67 22];
            app.Input_1.Value = 98.6;

            % Create RBWDropDownLabel
            app.RBWDropDownLabel = uilabel(app.Panel_3);
            app.RBWDropDownLabel.HorizontalAlignment = 'right';
            app.RBWDropDownLabel.Position = [17 403 93 24];
            app.RBWDropDownLabel.Text = '选择分辨率RBW';

            % Create RBWDropDown
            app.RBWDropDown = uidropdown(app.Panel_3);
            app.RBWDropDown.Items = {'300KHz', '100Hz', '1MHz', '3MHz', '10MHz', '100KHz', '30KHz', '10KHz', '3KHz', '1KHz', '300Hz'};
            app.RBWDropDown.Position = [135 404 100 22];
            app.RBWDropDown.Value = '300KHz';

            % Create MHzLabel
            app.MHzLabel = uilabel(app.Panel_3);
            app.MHzLabel.Position = [212 451 30 22];
            app.MHzLabel.Text = 'MHz';

            % Create Label_6
            app.Label_6 = uilabel(app.Panel_3);
            app.Label_6.HorizontalAlignment = 'center';
            app.Label_6.Position = [103 23 53 22];
            app.Label_6.Text = '调节增益';

            % Create Gain
            app.Gain = uiknob(app.Panel_3, 'continuous');
            app.Gain.Limits = [0 70];
            app.Gain.Position = [87 58 83 83];
            app.Gain.Value = 20;

            % Create DropDown_2
            app.DropDown_2 = uidropdown(app.Panel_3);
            app.DropDown_2.Items = {'50MHz', '20MHz', '10MHz', '5MHz', '1MHz'};
            app.DropDown_2.Position = [134 359 100 22];
            app.DropDown_2.Value = '50MHz';

            % Create RBWDropDownLabel_2
            app.RBWDropDownLabel_2 = uilabel(app.Panel_3);
            app.RBWDropDownLabel_2.HorizontalAlignment = 'right';
            app.RBWDropDownLabel_2.Position = [19 358 75 24];
            app.RBWDropDownLabel_2.Text = '选择分析带宽';

            % Create Button_2
            app.Button_2 = uibutton(app.Panel_3, 'push');
            app.Button_2.ButtonPushedFcn = createCallbackFcn(app, @Button_Stop, true);
            app.Button_2.BackgroundColor = [0 0 1];
            app.Button_2.FontSize = 14;
            app.Button_2.FontWeight = 'bold';
            app.Button_2.FontColor = [1 1 1];
            app.Button_2.Position = [80 188 100 28];
            app.Button_2.Text = '结束';

            % Create Panel
            app.Panel = uipanel(app.UIFigure);
            app.Panel.TitlePosition = 'centertop';
            app.Panel.Title = '频谱扫描';
            app.Panel.FontWeight = 'bold';
            app.Panel.FontSize = 16;
            app.Panel.Position = [265 -4 804 586];

            % Create UIAxes
            app.UIAxes = uiaxes(app.Panel);
            title(app.UIAxes, '频谱扫描结果')
            xlabel(app.UIAxes, '频率(MHz)')
            ylabel(app.UIAxes, '相对功率(dB)')
            zlabel(app.UIAxes, 'Z')
            app.UIAxes.Position = [255 53 545 501];

            % Create spec_sweep
            app.spec_sweep = uibutton(app.Panel, 'state');
            app.spec_sweep.ValueChangedFcn = createCallbackFcn(app, @Spec_sweep, true);
            app.spec_sweep.Text = '开始频谱扫描';
            app.spec_sweep.BackgroundColor = [0 0 1];
            app.spec_sweep.FontSize = 14;
            app.spec_sweep.FontWeight = 'bold';
            app.spec_sweep.FontColor = [1 1 1];
            app.spec_sweep.Position = [85 227 100 28];

            % Create Label_8
            app.Label_8 = uilabel(app.Panel);
            app.Label_8.HorizontalAlignment = 'right';
            app.Label_8.Position = [24 456 53 22];
            app.Label_8.Text = '起始频率';

            % Create EditField_2
            app.EditField_2 = uieditfield(app.Panel, 'numeric');
            app.EditField_2.Limits = [70 Inf];
            app.EditField_2.Position = [95 456 100 22];
            app.EditField_2.Value = 70;

            % Create EditField_3Label
            app.EditField_3Label = uilabel(app.Panel);
            app.EditField_3Label.HorizontalAlignment = 'right';
            app.EditField_3Label.Position = [24 414 53 22];
            app.EditField_3Label.Text = '截止频率';

            % Create EditField_3
            app.EditField_3 = uieditfield(app.Panel, 'numeric');
            app.EditField_3.Limits = [200 6000];
            app.EditField_3.Position = [95 414 100 22];
            app.EditField_3.Value = 200;

            % Create Label_9
            app.Label_9 = uilabel(app.Panel);
            app.Label_9.HorizontalAlignment = 'right';
            app.Label_9.Position = [24 375 41 22];
            app.Label_9.Text = '采样率';

            % Create EditField_4
            app.EditField_4 = uieditfield(app.Panel, 'numeric');
            app.EditField_4.Limits = [5 56];
            app.EditField_4.Position = [94 374 100 22];
            app.EditField_4.Value = 5;

            % Create MhzLabel_3
            app.MhzLabel_3 = uilabel(app.Panel);
            app.MhzLabel_3.Position = [203 458 28 22];
            app.MhzLabel_3.Text = 'Mhz';

            % Create MhzLabel_4
            app.MhzLabel_4 = uilabel(app.Panel);
            app.MhzLabel_4.Position = [203 414 28 22];
            app.MhzLabel_4.Text = 'Mhz';

            % Create MhzLabel_5
            app.MhzLabel_5 = uilabel(app.Panel);
            app.MhzLabel_5.Position = [203 376 28 22];
            app.MhzLabel_5.Text = 'Mhz';

            % Create Label_11
            app.Label_11 = uilabel(app.Panel);
            app.Label_11.HorizontalAlignment = 'center';
            app.Label_11.Position = [23 311 53 22];
            app.Label_11.Text = '扫描进度';

            % Create Gauge
            app.Gauge = uigauge(app.Panel, 'linear');
            app.Gauge.Position = [100 302 119 40];

            % Create Label_12
            app.Label_12 = uilabel(app.Panel);
            app.Label_12.HorizontalAlignment = 'right';
            app.Label_12.Position = [444 15 53 22];
            app.Label_12.Text = '扫描耗时';

            % Create EditField_5
            app.EditField_5 = uieditfield(app.Panel, 'numeric');
            app.EditField_5.Position = [512 15 100 22];

            % Create Label_13
            app.Label_13 = uilabel(app.Panel);
            app.Label_13.Position = [622 14 25 22];
            app.Label_13.Text = '秒';

            % Create Label_21
            app.Label_21 = uilabel(app.Panel);
            app.Label_21.HorizontalAlignment = 'right';
            app.Label_21.Position = [57 516 185 34];
            app.Label_21.Text = '绿灯：正在扫描；红灯：扫描结束';

            % Create Lamp_2
            app.Lamp_2 = uilamp(app.Panel);
            app.Lamp_2.Position = [28 524 18 18];
            app.Lamp_2.Color = [1 0 0];

            % Create Label_25
            app.Label_25 = uilabel(app.Panel);
            app.Label_25.HorizontalAlignment = 'center';
            app.Label_25.Position = [110 24 53 22];
            app.Label_25.Text = '调节增益';

            % Create Gain_2
            app.Gain_2 = uiknob(app.Panel, 'continuous');
            app.Gain_2.Limits = [0 70];
            app.Gain_2.Position = [94 59 83 83];
            app.Gain_2.Value = 20;

            % Create Button_3
            app.Button_3 = uibutton(app.Panel, 'push');
            app.Button_3.ButtonPushedFcn = createCallbackFcn(app, @Button_Stop, true);
            app.Button_3.BackgroundColor = [0 0 1];
            app.Button_3.FontSize = 14;
            app.Button_3.FontWeight = 'bold';
            app.Button_3.FontColor = [0.9412 0.9412 0.9412];
            app.Button_3.Position = [85 189 100 28];
            app.Button_3.Text = '结束';

            % Create Panel_2
            app.Panel_2 = uipanel(app.UIFigure);
            app.Panel_2.TitlePosition = 'centertop';
            app.Panel_2.Title = '模式识别';
            app.Panel_2.FontWeight = 'bold';
            app.Panel_2.FontSize = 16;
            app.Panel_2.Position = [1067 -3 404 585];

            % Create Label_14
            app.Label_14 = uilabel(app.Panel_2);
            app.Label_14.HorizontalAlignment = 'right';
            app.Label_14.Position = [2 521 89 22];
            app.Label_14.Text = '发射机调制模式';

            % Create ListBox
            app.ListBox = uilistbox(app.Panel_2);
            app.ListBox.Items = {'AM', 'FM', 'ASK', 'FSK', 'BPSK'};
            app.ListBox.Position = [106 453 100 92];
            app.ListBox.Value = 'AM';

            % Create Label_15
            app.Label_15 = uilabel(app.Panel_2);
            app.Label_15.HorizontalAlignment = 'center';
            app.Label_15.FontSize = 14;
            app.Label_15.Position = [213 312 131 22];
            app.Label_15.Text = '接收机进行模式识别';

            % Create Switch
            app.Switch = uiswitch(app.Panel_2, 'toggle');
            app.Switch.ValueChangedFcn = createCallbackFcn(app, @SwitchValueChanged, true);
            app.Switch.FontSize = 14;
            app.Switch.Position = [268 370 20 45];

            % Create Label_19
            app.Label_19 = uilabel(app.Panel_2);
            app.Label_19.HorizontalAlignment = 'right';
            app.Label_19.FontSize = 14;
            app.Label_19.Position = [79 268 103 22];
            app.Label_19.Text = '识别的调制模式';

            % Create CognMod
            app.CognMod = uieditfield(app.Panel_2, 'text');
            app.CognMod.Position = [197 268 100 22];

            % Create Label_20
            app.Label_20 = uilabel(app.Panel_2);
            app.Label_20.HorizontalAlignment = 'right';
            app.Label_20.Position = [219 496 53 22];
            app.Label_20.Text = '状态提示';

            % Create State
            app.State = uieditfield(app.Panel_2, 'text');
            app.State.Position = [287 496 101 22];

            % Create Label_22
            app.Label_22 = uilabel(app.Panel_2);
            app.Label_22.HorizontalAlignment = 'right';
            app.Label_22.FontSize = 14;
            app.Label_22.Position = [107 227 75 22];
            app.Label_22.Text = '识别匹配度';

            % Create CognBelief
            app.CognBelief = uieditfield(app.Panel_2, 'numeric');
            app.CognBelief.FontSize = 14;
            app.CognBelief.Position = [197 227 100 22];

            % Create Label_23
            app.Label_23 = uilabel(app.Panel_2);
            app.Label_23.Position = [308 228 25 22];
            app.Label_23.Text = '%';

            % Create Label_24
            app.Label_24 = uilabel(app.Panel_2);
            app.Label_24.HorizontalAlignment = 'center';
            app.Label_24.FontSize = 14;
            app.Label_24.Position = [62 311 131 22];
            app.Label_24.Text = '发射机发射调制信号';

            % Create Switch_2
            app.Switch_2 = uiswitch(app.Panel_2, 'toggle');
            app.Switch_2.ValueChangedFcn = createCallbackFcn(app, @Switch_2ValueChanged, true);
            app.Switch_2.FontSize = 14;
            app.Switch_2.Position = [117 369 20 45];

            % Create spec_sweep_2
            app.spec_sweep_2 = uibutton(app.Panel_2, 'state');
            app.spec_sweep_2.ValueChangedFcn = createCallbackFcn(app, @AM_modualte, true);
            app.spec_sweep_2.Text = 'AM调制度&交调测量';
            app.spec_sweep_2.BackgroundColor = [1 0.4118 0.1608];
            app.spec_sweep_2.FontSize = 14;
            app.spec_sweep_2.FontWeight = 'bold';
            app.spec_sweep_2.Position = [117 137 144 28];

            % Create mEditFieldLabel
            app.mEditFieldLabel = uilabel(app.Panel_2);
            app.mEditFieldLabel.HorizontalAlignment = 'right';
            app.mEditFieldLabel.Position = [100 94 54 22];
            app.mEditFieldLabel.Text = '调制度 m';

            % Create mEditField
            app.mEditField = uieditfield(app.Panel_2, 'text');
            app.mEditField.InputType = 'digits';
            app.mEditField.Position = [169 94 101 22];

            % Create IMDEditFieldLabel
            app.IMDEditFieldLabel = uilabel(app.Panel_2);
            app.IMDEditFieldLabel.HorizontalAlignment = 'right';
            app.IMDEditFieldLabel.Position = [76 59 78 22];
            app.IMDEditFieldLabel.Text = '交调失真 IMD';

            % Create IMDEditField
            app.IMDEditField = uieditfield(app.Panel_2, 'text');
            app.IMDEditField.InputType = 'digits';
            app.IMDEditField.Position = [169 59 101 22];

            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = finalwork

            % Create UIFigure and components
            createComponents(app)

            % Register the app with App Designer
            registerApp(app, app.UIFigure)

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)

            % Delete UIFigure when app is deleted
            delete(app.UIFigure)
        end
    end
end