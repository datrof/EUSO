%Alexandr Belov
%Daniil Trofimov
function calibration_function()
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
    show_part = input('Show part of the PMTs - 1, All PMTs - 0: '); %показ части установки
    % calibr = 1 - старая программа, calibr = 8 - для одного pmt, calibr = 16
    % для одного ec
    kpmt = 4;
    ipmt = -1; %начальный pmt для calibr = 8. ipmt = 0 калибровка одного заданного pmt
    dac = 0; %изменение порогов для всего прибора от 0 до 1020 с шагом 10
    if show_part == 1
        calibr = input('Make calibration: 0 - no, 8 - yes: ');
        if calibr == 8
            ipmt = input('Enter calibration number: 0 - calibration PMT, 1 - calibration EC: ');
            if ipmt == 0
                nump = input('Enter PMT number (from 1 to 36): ');
            elseif ipmt == 1
                nume = input('Enter EC number (from 1 to 9): ');
            else
                print('Error');
            end
        end
        if calibr == 0
            dac = input('Make s-curve: 0 - no, 1 - yes: ');
            nump = input('Enter PMT number (from 1 to 36): ');
        end
    end
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


    while 1 == 1
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
            pdm_2d_remap = rotate_pmt(pdm_2d_remap_old);
        end
    
    
    if show_part==1
        if fix_color_map==1
            imagesc(double(pdm_2d_remap(1:48,1:16))/16384, clims);
        else
            calibrmatrix = num_pmt(nump, double(pdm_2d_remap)/16384); % было 33:40,1:8 без перестроения
            % калибровка 8х8 со встроенным движением    
            if calibr == 8
                % номера pmt и ec
                if ipmt == 0
                    Aa = num_pmt(nump, double(pdm_2d_remap)/16384);
                else
                    [nec, pmt1, pmt2, pmt3, pmt4] = num_ec(nume, double(pdm_2d_remap)/16384);
                end
                %выбор нужного pmt
                if ipmt == 1
                    Aa = pmt1;
                elseif ipmt == 2
                    Aa = pmt2;
                elseif ipmt == 3
                    Aa = pmt3;
                elseif ipmt == 4
                    Aa = pmt4;
                end
                if ipmt == 0
                    imagesc(Aa);
                else
                    imagesc(nec);
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
                                    ! ./move_led_rel.py -mmx 33.8 -mmy -11.52;
                                    %-mmx 35 -mmy -10;
                                elseif ipmt == 3
                                    ! ./move_led_rel.py -mmx 8.64 -mmy 13.64;
                                    % -mmx 10 -mmy 15;
                                elseif ipmt == 4
                                    ! ./move_led_rel.py -mmx -25.16 -mmy -11.52;
                                    % -25, -10 
                                elseif ipmt == 5
                                    ! ./move_led_rel.py -mmx 8.64 -mmy -36.68;
                                    % 10, -35
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
           
            else
                imagesc(calibrmatrix); %стандарт 1:48
                countav = countav + 1;
                % снятие s-curve
                if dac == 1 %автоматизация процесса
                    %if countav > 1 %исключение первого кадра
                    At = At + calibrmatrix;  
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
                           dlmwrite('sc.txt',' ','-append');
                           dlmwrite('sc.txt',MVav,'-append');
                        end 
                    end
                end
            end
        end
    else
        if fix_color_map==1
            imagesc(double(pdm_2d_remap)/16384, clims);
        else
            imagesc(double(pdm_2d_remap)/16384);
            %Am1 = double(pdm_2d_remap(17:32,33:48))/16384;
            %Am2 = double(pdm_2d_remap(33:48,33:48))/16384;
            Am1 = double(pdm_2d_remap(25:32,9:16))/16384;
            mean(mean(Am1))
        end    
    end
    colorbar;
    pause(0.01)   %0.1sec
    end
    fclose(t);
end


function res = remap_spb2(a)

    res(1,:)= [a(1,7) a(1,5) a(1,3) a(1,1) a(2,4) a(2,2) a(1,8) a(1,6)];%0-7
    res(2,:)= [a(2,8) a(2,6) a(2,3) a(2,1) a(2,7) a(2,5) a(1,2) a(1,4)];%8-15
    res(3,:)= [a(3,8) a(3,6) a(3,4) a(3,2) a(3,7) a(3,5) a(3,3) a(3,1)];%16-23
    res(4,:)= [a(4,2) a(4,4) a(4,6) a(4,8) a(4,7) a(4,5) a(4,3) a(4,1)];%24-31
    res(5,:)= [a(6,1) a(5,7) a(5,5) a(5,3) a(5,1) a(5,2) a(5,4) a(5,6)];%32-39
    res(6,:)= [a(6,3) a(6,5) a(6,7) a(7,1) a(5,8) a(6,2) a(6,4) a(6,6)];%40-47
    res(7,:)= [a(7,3) a(7,6) a(7,8) a(8,2) a(6,8) a(7,2) a(7,4) a(7,5)];%48-55-
    res(8,:)= [a(8,4) a(8,5) a(8,6) a(8,7) a(7,7) a(8,1) a(8,3) a(8,8)];%56-63

end

function res = rotate_pmt(a)
    for i=0:5
       for xi=1:8
          res(i*8+1:i*8+8, xi) = a((5-i)*8+1:(5-i)*8+8, 9 - xi);
       end 
    end
    for i=0:5
       for yi=1:8
          res(i*8+yi, 9:16) = a(i*8+9-yi, 9:16);
       end 
    end
end

function res = num_pmt(num, A) %num from 1 to 36
    yn = fix((num-1)/6); % расчет координаты по х
    xn = mod(num-1, 6);
    res = A(xn*8+1:xn*8+8,yn*8+1:yn*8+8);
end

function [nec, pmt1, pmt2, pmt3, pmt4] = num_ec(num, A) %num from 1 to 9
    yn = fix((num-1)/3); % расчет координаты по х
    xn = mod(num-1, 3);
    nec = A(xn*16+1:xn*16+16,yn*16+1:yn*16+16);
    pmt1 = A(xn*16+1:xn*16+8,yn*16+1:yn*16+8);
    pmt2 = A(xn*16+1:xn*16+8,yn*16+9:yn*16+16);
    pmt3 = A(xn*16+9:xn*16+16,yn*16+9:yn*16+16);
    pmt4 = A(xn*16+9:xn*16+16,yn*16+1:yn*16+8);
end
