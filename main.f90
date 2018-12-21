!-------------------------------------------------------
! Written by Wei Xiong,@THU
! Revised by Shuping Jiao,@THU,Mar 2015
!------------------------------------------------------- 
!=============�û�����===============
module global_data
implicit none
double precision,parameter::PI=3.1415926536
character(14),save::init_struct_filename= 'water-graphene' ! lammps��ʼ�����ļ�
character(18)::traj_filename= 'atomacc.xyz' ! �켣�����ļ�
!integer,parameter::fileunit=111
integer,parameter::num_frames=1010 ! ԭ�������ļ�����֡��
double precision,parameter::eq_time=2900.0 ! ϵͳ�ﵽƽ���ʱ�䣬��λps
double precision,parameter::timestep=0.001 ! ʱ�䲽������λps
integer::col,row ! ���ܶ���ͼ����
double precision,parameter::grid_size=0.3 ! ��λAngstroms
integer,parameter::split_num=36 ! -90�ȵ�90�ȷ�36��ͳ��ˮ���Ӹ���
!����ֲ�����
double precision,parameter::delta=0.05,cutoff=10.0 ! ��λAngstroms
double precision,parameter::z_lower=-6.44716,z_upper=-5.94716 ! ��λAngstroms
integer::layer
double precision,allocatable::g_global(:)
double precision::rho_mean ! ����ֲ������е�ƽ���ܶ�
!--------------------------------------------
double precision::q1,q2,qcos,qsin
double precision::num_water_1st ! ����ʯīϩ����ĵ�һ��ˮ���ӵ���Ŀ
integer,parameter::num_q=45,num_theta=72
double precision::struct_factor(0:num_q,0:num_theta)
double precision::struct_mean(0:num_q)
!--------------------------------------------------------
!atom_info���������ӱ�ţ�ԭ�����࣬ԭ������������Լ�����
type atom_info
integer::molecule_id, atom_kind ! ���ӱ��, ԭ������
double precision::mass,charge! ����,���
double precision::coords(3) ! ԭ������
end type atom_info
!water_info������1��ˮ������1����ԭ�Ӻ�2����ԭ�ӱ�� 
type water_info
integer::oxygen_id, hydrogen1_id, hydrogen2_id ! ˮ��������ԭ�ӡ�������ԭ�ӵı��
end type water_info
!--------------------------------------------------------
integer,save::num_atom_total,num_bond_total,num_angle_total ! ԭ�ӡ����ͼ�����Ŀ
integer,save::num_atomtype,num_bondtype,num_angletype ! ԭ�ӡ����ͼ��ǵ�������Ŀ
integer,save::num_water_total ! ˮ������Ŀ
double precision,save::time
double precision,save::xlo,xhi,ylo,yhi,zlo,zhi ! ģ����ӳߴ�
double precision,allocatable,save::masses(:) ! ��ͬ����ԭ�ӵ�����
type(atom_info),allocatable,save::atoms(:) ! ԭ����Ϣ����
type(water_info),allocatable,save::waters(:) ! ˮ������Ϣ����
end module

!------------------------------------------
!������ˮ���ӽṹ�ķ���
!------------------------------------------
!�����򣬺����������ڡ�ͨ������lammps�ĳ�ʼ�����ļ���ʼ��ԭ��ϵͳ
!ʹ��atom type�����ݽṹ�洢����ԭ����Ϣ
program water_structure
use global_data
implicit none
integer::frame,i,j
integer::eff_frames=0 ! ����ͳ�Ƶ���Ч֡��
call initial()
! ����ÿһ֡��ԭ������
open(111,file=traj_filename)
frame=1
do while(frame<=num_frames)
call update_coordinates()
if(time>eq_time) then
call selectwater()
eff_frames=eff_frames+1
call RDFs()
do i=0,num_q
do j=0,num_theta
qsin=(1.d0+1.d0*i/num_q*5.d0)*sin(1.d0*j/num_theta*2.d0*PI)
qcos=(1.d0+1.d0*i/num_q*5.d0)*cos(1.d0*j/num_theta*2.d0*PI)
call Struct(i,j)
end do
end do
end if
frame=frame+1
end do
open(333,file='goo_global.txt')
rho_mean=rho_mean/eff_frames
write(333,*) rho_mean/(z_upper-z_lower)/33.3d0*1000.d0 ! �ÿ���ˮ�ܶȹ�һ��
do i=1,layer
write(333,*) (1.d0*i-0.5d0)*delta,g_global(i)/rho_mean/eff_frames
end do
open(222,file='struct_factor.txt')
open(333,file='struct_factor_matlab.txt')
open(555,file='struct_mean.txt')
struct_factor=struct_factor/eff_frames
!��ͼ����
do i=0,num_q
do j=0,num_theta
write(222,*) 10.d0*(1.d0+1.d0*i/num_q*5.d0), 1.d0*j/num_theta*360.d0,struct_factor(i,j)
struct_mean(i)=struct_mean(i)+struct_factor(i,j)
end do
write(222,*)
struct_mean(i)=struct_mean(i)/(num_theta*1.d0+1)
write(555,*) 10.d0*(1.d0+1.d0*i/num_q* 5.d0),struct_mean(i)
end do

do i=num_q,0,-1
write(333,"(<num_theta+1>f12.4)") struct_factor(i,:)
end do
close(333)
end program water_structure

!-----------------------------
!�ӳ���1�����ݳ�ʼ��
!-----------------------------
subroutine initial()
use global_data
implicit none
integer::atom_id,water_id ! ԭ�ӱ��, ˮ���ӱ��
integer::i,k,temp_int
integer::step ! ����Ĳ���
open(10,file=init_struct_filename)
read(10,*)
read(10,*)
read(10,*) num_atom_total
read(10,*) num_bond_total
read(10,*) num_angle_total
num_water_total=num_angle_total ! ˮ���Ӹ������������е��ڼ�����Ŀ
read(10,*)
read(10,*) num_atomtype
read(10,*) num_bondtype
read(10,*) num_angletype
read(10,*)
read(10,*) xlo,xhi
read(10,*) ylo,yhi
read(10,*) zlo,zhi
do k=1,3
read(10,*)
end do
allocate(masses(num_atomtype))
allocate(atoms(num_atom_total))
allocate(waters(num_water_total))
col=ceiling((xhi-xlo)/grid_size)
row=ceiling((yhi-ylo)/grid_size)
layer=ceiling(cutoff/delta) ! RDFs�еĲ���
allocate(g_global(layer))
g_global=0.0
rho_mean=0.0

do i=1,num_atomtype
read(10,*) temp_int,masses(i)
end do
read(10,*)
read(10,*)
read(10,*)

do i=1,num_atom_total
read(10,*) atom_id,atoms(atom_id)%molecule_id,atoms(atom_id)%atom_kind,&
atoms(atom_id)%charge,atoms(atom_id)%coords
atoms(atom_id)%mass=masses(atoms(atom_id)%atom_kind)
if(atom_id/=i) write(*,*) 'numbers of atoms are disordered!'
end do
do k=1,3
read(10,*)
end do
do i=1,num_bond_total
read(10,*)
end do
do k=1,3
read(10,*)
end do

do i=1,num_water_total
read(10,*) water_id,temp_int,waters(water_id)%hydrogen1_id,&
waters(water_id)%oxygen_id,waters(water_id)%hydrogen2_id
if(water_id/=i) print *,'numbers of waters are disordered!'
end do
struct_factor=0.0
struct_mean=0.0
close(10)
end subroutine

!---------------------------
!�ӳ���2������ԭ��λ��
!---------------------------
subroutine update_coordinates()
use global_data
implicit none
integer::atom_id ! ԭ�ӱ��
integer::step ! ����Ĳ���
integer::i,k,temp_int
read(111,*)
read(111,*) step
do k=1,3
read(111,*)
end do
read(111,*) xlo,xhi
read(111,*) ylo,yhi
read(111,*) zlo,zhi
read(111,*)
time=timestep*step !��λps������lammps �жԵ�λ�Ķ�����ܲ�ͬ
do i=1,num_atom_total
! ����ԭ������
read(111,*) atom_id,temp_int,atoms(atom_id)%coords(:)
! ���ݹ켣�ļ����ص㣬�Ƿ���Ҫ��Ϊ��������
atoms(atom_id)%coords(1)=atoms(atom_id)%coords(1)*(xhi-xlo)+xlo
atoms(atom_id)%coords(2)=atoms(atom_id)%coords(2)*(yhi-ylo)+ylo
atoms(atom_id)%coords(3)=atoms(atom_id)%coords(3)*(zhi-zlo)+zlo
!�������Ҫת��������Ҫ����������ʽ��
!atoms(atom_id)%coords(1)=atoms(atom_id)%coords(1)
!atoms(atom_id)%coords(2)=atoms(atom_id)%coords(2)
!atoms(atom_id)%coords(3)=atoms(atom_id)%coords(3)
end do
end subroutine

!------------------------------------------
!�ӳ���3�����������ж���Ҫ������ˮ����
!------------------------------------------
! ͨ������lammps�Ĺ켣����ļ�����������ͳ����Ҫˮ���ӵ���Ŀ
! ���ڷǵ����ˮ�ṹ���������귶Χ���ֳ���Ҫͳ�Ƶ�ˮ����
subroutine selectwater()
use global_data
implicit none
integer::oxygen_id_temp
double precision::ztemp
integer::i,n
n=0
do i=1,num_water_total
oxygen_id_temp=waters(i)%oxygen_id
ztemp=atoms(oxygen_id_temp)%coords(3)
if(ztemp>z_lower .and. ztemp<=z_upper) then
n=n+1
end if
end do
num_water_1st=n
end subroutine

!---------------------------
!�ӳ���4����������ֲ�����
!---------------------------
! ͨ������lammps �Ĺ켣�ļ���ͳ�ƿ�������ĵ�һ��ˮ���� (��ʵ����ԭ��) ��
! ��ά���ھ���ֲ������Լ���һ��ˮ�Ľṹ����	
! ��һ��ˮ���ӵķ�Χ�����Ǿ������ʵģ����������3.0<d<=3.5 Angstroms
subroutine RDFs()
use global_data
implicit none
integer::oxygen_id_temp
integer,allocatable::oxygen_ids(:)
integer::i,j,n,iloop,jloop
double precision,allocatable::g(:)
double precision::ztemp
double precision::dx,dy,r,factor
double precision::xij,yij,zij
n=num_water_1st
allocate(oxygen_ids(n))
allocate(g(layer))
g=0.0
oxygen_ids=0
j=1
do i=1,num_water_total
oxygen_id_temp=waters(i)%oxygen_id
ztemp=atoms(oxygen_id_temp)%coords(3)
if(ztemp>z_lower .and. ztemp<=z_upper) then
oxygen_ids(j)=oxygen_id_temp
j=j+1
end if
end do
dx=xhi-xlo
dy=yhi-ylo
do i=1,n
! ��������ֲ�����RDF
do j=1,n
! ���������Ա߽��������־Ÿ��������
do iloop=-1,0,1
do jloop=-1,0,1
xij=atoms(oxygen_ids(i))%coords(1)-atoms(oxygen_ids(j))%coords(1)
yij=atoms(oxygen_ids(i))%coords(2)-atoms(oxygen_ids(j))%coords(2)
zij=atoms(oxygen_ids(i))%coords(3)-atoms(oxygen_ids(j))%coords(3)
r=sqrt((xij+iloop*dx)**2+(yij +jloop*dx)**2+zij**2)
if(r>delta/10.d0 .and. r<=cutoff) then
g(ceiling(r/delta))=g(ceiling(r/delta))+1.d0
end if
end do
end do
end do
end do
rho_mean=rho_mean+n/dx/dy
do i=1,layer
factor=2.d0*PI*delta*(i-0.5d0)*delta
g(i)=g(i)/n/factor
g_global(i)=g_global(i)+g(i)
end do
deallocate(oxygen_ids)
deallocate(g)
end subroutine

!-----------------------------------
!�ӳ���5��ͳ�ƽ�����ˮ�Ľṹ����
!-----------------------------------
! ͨ������lammps �Ĺ켣����ļ���ͳ�ƿ�������ĵ�һ��ˮ�Ľṹ����
! ��һ��ˮ���ӵķ�Χ�����Ǿ������ʵģ����������3.0<d<=3.5 Angstroms	
subroutine Struct(k,l)
use global_data
implicit none
integer,allocatable::oxygen_ids(:)
integer::oxygen_id_temp
integer::i,j,n,k,l
double precision::ztemp
double precision::struct_factor_cos,struct_factor_sin
double precision::x,y,z
n=num_water_1st
allocate(oxygen_ids(n))
struct_factor_cos=0.0
struct_factor_sin=0.0
j=1
do i=1,num_water_total
oxygen_id_temp=waters(i)%oxygen_id
ztemp= atoms(oxygen_id_temp)%coords(3)
if(ztemp>z_lower .and. ztemp<=z_upper) then
oxygen_ids(j)=oxygen_id_temp
j=j+1
end if
end do
do i=1,n
! ��ṹ����
x=atoms(oxygen_ids(i))%coords(1)
y=atoms(oxygen_ids(i))%coords(2)
z=atoms(oxygen_ids(i))%coords(3)
struct_factor_sin=struct_factor_sin+sin(x*qcos+y*qsin)
struct_factor_cos=struct_factor_cos+cos(x*qcos+y*qsin)
end do
struct_factor(k,l)=struct_factor(k,l)+(struct_factor_cos**2+struct_factor_sin**2)/n
end subroutine

 

