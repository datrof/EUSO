function res=remap_spb2(a)
%res = a;%zeros(8,8);
%a=fliplr(a);
%a=rot90(a,0);
%res(1,:)= [a(1,1) a(1,5) a(1,6) a(1,7) a(1,8) a(1,2) a(2,5) a(2,6)];%0-7
%res(2,:)= [a(2,6) a(1,4) a(2,7) a(2,1) a(2,2) a(2,8) a(2,3) a(3,5)];%8-15
%res(3,:)= [a(2,4) a(3,6) a(3,1) a(3,7) a(3,2) a(3,8) a(3,3) a(4,8)];%16-23
%res(4,:)= [a(3,4) a(4,7) a(4,1) a(4,6) a(4,2) a(4,5) a(4,3) a(4,4)];%24-31
%res(5,:)= [a(5,5) a(5,4) a(5,6) a(5,3) a(5,7) a(5,2) a(5,8) a(5,1)];%32-39
%res(6,:)= [a(6,8) a(6,4) a(6,7) a(6,3) a(6,6) a(6,2) a(6,5) a(6,1)];%40-47
%res(7,:)= [a(7,8) a(7,4) a(7,7) a(7,3) a(8,4) a(7,6) a(8,3) a(7,5)];%48-55-
%res(8,:)= [a(8,2) a(8,8) a(8,1) a(8,7) a(7,1) a(8,6) a(7,2) a(8,5)];%56-63

res(1,:)= [a(1,7) a(1,5) a(1,3) a(1,1) a(2,4) a(2,2) a(1,8) a(1,6)];%0-7
res(2,:)= [a(2,8) a(2,6) a(2,3) a(2,1) a(2,7) a(2,5) a(1,2) a(1,4)];%8-15
res(3,:)= [a(3,8) a(3,6) a(3,4) a(3,2) a(3,7) a(3,5) a(3,3) a(3,1)];%16-23
res(4,:)= [a(4,2) a(4,4) a(4,6) a(4,8) a(4,7) a(4,5) a(4,3) a(4,1)];%24-31
res(5,:)= [a(6,1) a(5,7) a(5,5) a(5,3) a(5,1) a(5,2) a(5,4) a(5,6)];%32-39
res(6,:)= [a(6,3) a(6,5) a(6,7) a(7,1) a(5,8) a(6,2) a(6,4) a(6,6)];%40-47
res(7,:)= [a(7,3) a(7,6) a(7,8) a(8,2) a(6,8) a(7,2) a(7,4) a(7,5)];%48-55-
res(8,:)= [a(8,4) a(8,5) a(8,6) a(8,7) a(7,7) a(8,1) a(8,3) a(8,8)];%56-63
