%Alexandr Belov
%Daniil Trofimov

clear all;
% setup parameters
n_ecasic=6;
dimx_ecasic = 8;
dimy_ecasic = 48;
ipaddr = '192.168.7.10';
port = 23;

fix_color_map = 0;
colorbar_lim = 63;%45 %установить предел цветовой шкалы / set colorbar limit

do_remap = 1; %перастановка пикселей
do_rotate = 1; %перестановка и поворот pmt
show_part = 1; %показ части установки
% calibr = 1 - старая программа, calibr = 8 - для одного pmt, calibr = 16
% для одного ec
calibr = 8; 
kpmt = 4;
ipmt = 1; %начальный pmt для calibr = 8. ipmt = 0 калибровка одного заданного pmt
dac = 0; %изменение порогов для всего прибора от 0 до 1020 с шагом 10

%open tcp connection
t = tcpip(ipaddr, port, 'NetworkRole', 'client', 'InputBufferSize', 10000);
fopen(t);

%fwrite(t, 'acq test 2');T
%[pdm_data, count] = fread(t, 5, 'uint32');
Amax = zeros(8);
Aav = zeros(8);
BAav = zeros(16);
At = zeros(8);
Vmax = zeros(1,64);
Vav = zeros(1,64); %калибровочный вектор
BVav = zeros(1,256); %калибровочный вектор для 16х16
MVav = zeros(103,65); %результаты калибровки по порогам
cavel = 0;
numoprev = -1; %предыдущий номер пикселя
matrixfile = fopen('my.matrix','w');
alivepixels = 64;
lpixels = 0;
countav = 0;
ncountav = 0; %начальный порог, дел на 10

% calibr == 8
begincalibration = 0; %начало калибровки
begincorner = 0; %начало перемещения в угол
beginx = 0;
beginy = 0;
tocenter = 0; %перемещение в центр
stepx = 0;
stepy = 0;
calpix = 0;
xp = 1;
yp = 1;
movx = 1;
movy = 1;

daclevel = num2str(10*ncountav);
if dac == 1 % Задание начального порога
    fwrite(t, strcat('slowctrl all dac ',daclevel));  %порог 0
    [msg_reply, count] = fread(t, 5, 'char'); 
end


for i=1:100000
    % acquire one frame
    fwrite(t, 'acq live');
    [pdm_data, count] = (fread(t, 2304, 'uint32'));
    pdm_data = swapbytes(uint32(pdm_data));

    % obtain 6 images from EC-ASIC boards. Each  EC-ASIC board has 8x48 image
    ecasics_2d = reshape(pdm_data, [dimx_ecasic dimy_ecasic n_ecasic]); 
    % concatenation of 6 images into one image 48x48
    pdm_2d = [ecasics_2d(:,:,1)' ecasics_2d(:,:,2)' ecasics_2d(:,:,3)' ecasics_2d(:,:,4)' ecasics_2d(:,:,5)' ecasics_2d(:,:,6)'];
    % plot 2D image
    clims = [0 colorbar_lim];
    %pcolor(double(pdm_2d)/16384);    
    %imagesc(double(pdm_2d(1:16,17:24))/16384);
    
    if do_remap == 1
        for i=0:5
            for j=0:5
                pdm_2d_remap(i*8+1:i*8+8, j*8+1:j*8+8)=remap_spb2(pdm_2d(i*8+1:i*8+8, j*8+1:j*8+8));
            end
        end
    else
        pdm_2d_remap = pdm_2d;
    end
    
    if do_rotate == 1
        pdm_2d_remap_old = pdm_2d_remap;
        for i=0:5
            for xi=1:8
                pdm_2d_remap(i*8+1:i*8+8, xi) = pdm_2d_remap_old((5-i)*8+1:(5-i)*8+8, 9 - xi);
            end 
        end
        for i=0:5
            for yi=1:8
                pdm_2d_remap(i*8+yi, 9:16) = pdm_2d_remap_old(i*8+9-yi, 9:16);
            end 
        end
    end
    
    
    if show_part==1
        if fix_color_map==1
            imagesc(double(pdm_2d_remap(1:48,1:16))/16384, clims);
        else
            calibrmatrix = double(pdm_2d_remap(1:16,1:16))/16384; % было 33:40,1:8 без перестроения
            if calibr==1 %калибровка без встроенного движения системы
                Aa = calibrmatrix;  
                imagesc(Aa);
                %maxel = max(Aa); % определение максимального элемента
                [maxel,numo] = max(Aa(:));
                nx = fix((numo-1)/8)+1; % исправление вылета программы
                ny = mod(numo, 8);
                if ny == 0
                    ny = 8;
                end   
                % Метод определения максимального числа в пикселе
                if maxel > Amax(ny,nx) 
                    Amax(ny,nx) = maxel; % запись максимального числа в матрицу
                    Vmax(1,numo) = maxel; % запись максимального числа в матрицу в векторном представлении
                    fwrite(matrixfile,8);
                end 
                %fwrite(matrixfile,maxel);
                
                % Метод нахождения средних потоков по пикселям
                if numo == numoprev 
                    avel = avel + maxel;
                    cavel = cavel + 1;
                else
                    if cavel ~= 0
                        avel = round(avel/cavel, 4);
                        if Aav(nyp,nxp) == 0
                            lpixels = lpixels + 1;
                        end
                        if avel > Aav(nyp,nxp)
                            Aav(nyp,nxp) = avel; % запись среднего числа в матрицу
                            Vav(1,numoprev) = avel; % запись среднего числа в матрицу в векторном представлении
                        end
                    end
                    numoprev = numo; %переход на следующий пиксель
                    nyp = ny;
                    nxp = nx;
                    avel = 0; %обнуление переменных
                    cavel = 0;
                 end 
                
                %dlmwrite('Amaxtemp.txt',Amax);
                %dlmwrite('Aavtemp.txt',Aav);
                if lpixels>=alivepixels  %изменить
                    dlmwrite('Amax.txt',Amax,'-append');
                    dlmwrite('Amax.txt',' ','-append');
                    dlmwrite('Aav.txt',Aav,'-append');
                    dlmwrite('Aav.txt',' ','-append');
                    dlmwrite('Vmax.txt',Vmax,'-append');
                    dlmwrite('Vav.txt',Vav,'-append');
                    lpixels = 0;
                end
            % калибровка 8х8 со встроенным движением    
            elseif calibr == 8
                %выбор нужного pmt
                if ipmt == 1 || ipmt == 0 
                    Aa = double(pdm_2d_remap(1:8,1:8))/16384; 
                elseif ipmt == 2
                    Aa = double(pdm_2d_remap(1:8,9:16))/16384; 
                elseif ipmt == 3
                    Aa = double(pdm_2d_remap(9:16,9:16))/16384; 
                elseif ipmt == 4
                    Aa = double(pdm_2d_remap(9:16,1:8))/16384; 
                end
                if ipmt == 0
                    imagesc(Aa);
                else
                    imagesc(double(pdm_2d_remap(1:16,1:16))/16384)
                end
                %максимум матрицы
                [maxel,numo] = max(Aa(:));
                nx = fix((numo-1)/8)+1; % расчет координаты по х
                ny = mod(numo, 8);
                if ny == 0
                    ny = 8;
                end 

                % калибровка - действие 4
                if begincalibration == 2
                    pz = maxel - Aa(yp,xp)
                    if pz ~= 0 && Aa(yp,xp) ~= 0
                        calpix = calpix + maxel;
                    else
                        calpix = calpix + Aa(yp,xp);
                    end;
                    countav = countav + 1;
                    if countav >= 10 % число усреднения
                        Aav(yp,xp) = calpix/countav;
                        Vav(1,(xp-1)*8+yp) = Aav(yp,xp);
                        calpix = 0;
                        countav = 0;
                        if stepx == 7
                            yp = yp + 1;
                            movx = movx*(-1);
                            stepx = 0;
                            stepy = stepy + 1;
                            ! ./move_led_rel.py -mmx 0 -mmy 2.88;
                        else
                            if movx == 1
                                ! ./move_led_rel.py -mmx 2.88 -mmy 0;
                            elseif movx == -1
                                ! ./move_led_rel.py -mmx -2.88 -mmy 0;
                            end
                            xp = xp + movx;
                            stepx = stepx + 1;
                        end
                        % запись и перемещение к другому pmt - действие 5
                        if stepy == 8
                             if ipmt == 0
                                begincalibration = 3;
                                dlmwrite('calibration7.txt',Vav,'-append');
                                ! ./move_led_rel.py -mmx 0 -mmy -23.04;
                            else
                                begincalibration = 0; %начало калибровки
                                begincorner = 0; %начало перемещения в угол
                                beginx = 0;
                                beginy = 0;
                                stepx = 0;
                                stepy = 0;
                                calpix = 0;
                                tocenter = 0;
                                xp = 1;
                                yp = 1;
                                movx = 1;
                                movy = 1;
                                name = strcat(num2str(ipmt),'.txt');
                                dlmwrite(name,Vav,'-append');
                                ipmt = ipmt +1;
                                if ipmt == 2
                                    ! ./move_led_rel.py -mmx 35 -mmy -10;
                                elseif ipmt == 3
                                    ! ./move_led_rel.py -mmx 10 -mmy 15;
                                elseif ipmt == 4
                                    ! ./move_led_rel.py -mmx -25 -mmy -10;
                                elseif ipmt == 5
                                    ! ./move_led_rel.py -mmx 10 -mmy -35;
                                    begincalibration = 3;
                                end  
                            end
                        end
                    end
                end
                            
                % перемещение в начало - действие 3            
                if begincorner == 1
                    for xi=1:(nx-1)
                        ! ./move_led_rel.py -mmx -2.88 -mmy 0;
                    end
                    for yi=1:(ny-1)
                        ! ./move_led_rel.py -mmx 0 -mmy -2.88;
                    end
                    begincalibration = 2;
                    begincorner = 0;
                end;
                
                % выставление по центру пикселя - действие 2
                if tocenter == 1
                    de = maxel/100;
                    if Aa(ny-1,nx) - Aa(ny+1,nx) > de 
                        ! ./move_led_rel.py -mmx 0 -mmy 0.03;
                    elseif Aa(ny-1,nx) - Aa(ny+1,nx) < -de
                        ! ./move_led_rel.py -mmx 0 -mmy -0.03;
                    else
                        beginy = 1;
                    end
                    if Aa(ny,nx-1) - Aa(ny,nx+1) > de
                        ! ./move_led_rel.py -mmx 0.03 -mmy 0;
                    elseif Aa(ny,nx-1) - Aa(ny,nx+1) < -de
                        ! ./move_led_rel.py -mmx -0.03 -mmy 0;
                    else
                        beginx = 1;
                    end
                    if beginx == 1 && beginy == 1 
                        begincorner = 1;
                        tocenter = 0;
                    end
                end
                
                %отход от края - действие 1
                if begincalibration == 0
                    if ny == 1
                        ! ./move_led_rel.py -mmx 0 -mmy 5.76;
                    elseif ny == 8
                        ! ./move_led_rel.py -mmx 0 -mmy -5.76;
                    end
                
                    if nx == 1
                        ! ./move_led_rel.py -mmx 5.76 -mmy 0;
                    elseif nx == 8
                        ! ./move_led_rel.py -mmx -5.76 -mmy 0;
                    end
                    
                    tocenter = 1;
                    begincalibration = 1;
                end
% ==========================================================================
            % калибровка по ec юниту, плохо работает из-за относительного
            % смещения pmt друг относительно друга.
            elseif calibr == 16
                Aa = double(pdm_2d_remap(1:16,1:16))/16384;
                imagesc(Aa);
                [maxel,numo] = max(Aa(:));
                nx = fix((numo-1)/16)+1; % расчет координаты по х
                ny = mod(numo, 16);
                if ny == 0
                    ny = 16;
                end 

                
                if begincalibration == 2
                    pz = maxel - Aa(yp,xp)
                    calpix = calpix + Aa(yp,xp);
                    countav = countav + 1;
                    if countav >= 20 % число усреднения
                        BAav(yp,xp) = calpix/countav;
                        BVav(1,(xp-1)*16+yp) = BAav(yp,xp);
                        calpix = 0;
                        countav = 0;
                        if stepx == 15
                            yp = yp + 1;
                            movx = movx*(-1);
                            stepx = 0;
                            stepy = stepy + 1;
                            ! ./move_led_rel.py -mmx 0 -mmy 2.88;
                            if stepy == 8
                                ! ./move_led_rel.py -mmx 0 -mmy 5;
                            end
                        else
                            if movx == 1
                                ! ./move_led_rel.py -mmx 2.88 -mmy 0;
                                if stepx == 7
                                    ! ./move_led_rel.py -mmx 5 -mmy 0;
                                end
                            elseif movx == -1
                                ! ./move_led_rel.py -mmx -2.88 -mmy 0;
                                if stepx == 7
                                    ! ./move_led_rel.py -mmx -5 -mmy 0;
                                end
                            end
                            xp = xp + movx;
                            stepx = stepx + 1;
                        end
                        if stepy == 16
                            begincalibration = 3;
                            dlmwrite('calibration2711.txt',BVav,'-append');
                            ! ./move_led_rel.py -mmx 0 -mmy -51.08;
                        end
                    end
                end
                            
                            
                if begincorner == 1
                    for xi=1:(nx-1)
                        ! ./move_led_rel.py -mmx -2.88 -mmy 0;
                        if xi == 8
                            ! ./move_led_rel.py -mmx -5 -mmy 0;
                        end
                    end
                    for yi=1:(ny-1)
                        ! ./move_led_rel.py -mmx 0 -mmy -2.88;
                        if yi == 8
                            ! ./move_led_rel.py -mmx 0 -mmy -5;
                        end
                    end
                    begincalibration = 2;
                    begincorner = 0;
                end;
                if tocenter == 1
                    de = maxel/100;
                    if Aa(ny-1,nx) - Aa(ny+1,nx) > de 
                        ! ./move_led_rel.py -mmx 0 -mmy 0.03;
                    elseif Aa(ny-1,nx) - Aa(ny+1,nx) < -de
                        ! ./move_led_rel.py -mmx 0 -mmy -0.03;
                    else
                        beginy = 1;
                    end
                    if Aa(ny,nx-1) - Aa(ny,nx+1) > de
                        ! ./move_led_rel.py -mmx 0.03 -mmy 0;
                    elseif Aa(ny,nx-1) - Aa(ny,nx+1) < -de
                        ! ./move_led_rel.py -mmx -0.03 -mmy 0;
                    else
                        beginx = 1;
                    end
                    if beginx == 1 && beginy == 1 
                        begincorner = 1;
                        tocenter = 0;
                    end
                end
                if begincalibration == 0
                    if ny == 1 || ny == 9
                        ! ./move_led_rel.py -mmx 0 -mmy 5.76;
                    elseif ny == 8 || ny == 16
                        ! ./move_led_rel.py -mmx 0 -mmy -5.76;
                    end
                
                    if nx == 1 || nx == 9
                        ! ./move_led_rel.py -mmx 5.76 -mmy 0;
                    elseif nx == 8 || nx == 16
                        ! ./move_led_rel.py -mmx -5.76 -mmy 0;
                    end
                    
                    tocenter = 1;
                    begincalibration = 1;
                end
%==========================================================================            
            else
                if calibr == 2 %калибровка 1 пикселя
                    Aa = calibrmatrix; % было 33:40,1:8 без перестроения
                    imagesc(Aa);
                    dlmwrite('pix44.txt',Aa(4,4),'-append');
                else
                    imagesc(calibrmatrix); %стандарт 1:48
                    countav = countav + 1;
                    % снятие s-curve
                    if dac == 1 %автоматизация процесса
                        %if countav > 1 %исключение первого кадра
                        At = At + double(pdm_2d_remap(9:16,1:8))/16384;  
                        %end
                        if countav >= 20 % число усреднения
                            Aav = At/countav;
                            At = 0;
                            countav = 0;
                            ncountav = ncountav + 1;
                            daclevel = num2str(10*ncountav)
                            fwrite(t, strcat('slowctrl all dac ',daclevel));  % Задание порога
                            [msg_reply, count] = fread(t, 5, 'char'); 
                            pause(1.0);
                            MVav(ncountav,1) = 10*(ncountav-1);
                            for i=1:8
                                MVav(ncountav,(i-1)*8+2:(i-1)*8+9) = Aav(:,i);
                            end
                            if ncountav == 103
                                dac = 0;
                            end 
                        end
                    end
                end
            end
        end
    else
        if fix_color_map==1
            imagesc(double(pdm_2d_remap)/16384, clims);
            %imagesc(double(pdm_2d_remap(1:16,9:16))/16384);
        else
            %imagesc(double(pdm_2d_remap(1:16,9:16))/16384);
            %imagesc(double(pdm_2d(33:48,9:16))/16384);
            imagesc(double(pdm_2d_remap)/16384);
            %imagesc(double(pdm_2d));
        end    
    end
    %imagesc(double(pdm_2d));
    colorbar;

    pause(0.01)   %0.1sec
end


%% close tcp
fclose(t);
'port closed'
