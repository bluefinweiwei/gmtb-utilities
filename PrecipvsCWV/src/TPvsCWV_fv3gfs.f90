! stratify precipitation (%) with 1-mm-wide bins of the column water vapor (CWV; mm or kg/ m^2)
! ECMWF GRIB_API is required
! ifort **.f90 -I$GRIB_API/include -L$GRIB_API/lib -lgrib_api_f90
! contact: Weiwei Li (weiweili@ucar.edu) and Zhuo Wang (zhuowang@illinois.edu)

include 'grib_api_decode.f' ! subroutine to decode GRIB data

program main
implicit none

integer, parameter:: y1=beg_y, y2=end_y, m1=beg_m, m2=end_m, h1=00, h2=00
integer, parameter:: nlon=num_x, nlat=num_y
integer, parameter:: tmax=dmax, nbs=1
real, dimension(nbs):: sb,nb,wb,eb
!tropical belt around the globe (in degree)
data sb/YY1/
data nb/YY2/
data wb/XX1/
data eb/XX2/
integer lat1,lat2,lon1,lon2,nlat2

integer, parameter:: nz=num_selz
integer, dimension(nz):: alev
data alev/sellevs/

integer, parameter:: nfcst=num_fcst
integer, dimension(nfcst):: fcst
data fcst/selfcst/

character*200 year*4, mon*2, day*2, hour*2, lead*3
character*10, parameter:: shortnm0='vnamep',shortnm1='vnamepw',shortnm2='vnamelmsk'
! stratify bins for CWV
integer, parameter:: nbin=nbb
real, parameter:: pwmax=cwv1,pwmin=cwv0,step=(pwmax-pwmin)/real(nbin-1)

! stratify bins for Precip
integer, parameter:: nbinp=nbbp
real, parameter:: pmax=precip1,pmin=precip0,pstep=(pmax-pmin)/real(nbinp-1)

real,parameter:: dmiss=-9.99e+08
real, dimension(nlon,nlat):: ldmask,pw
real, dimension(nlon,nlat,nz):: var
real, dimension(nbin):: var_sum, var_str, nn_sum, nn_sum_p
real, dimension(nbinp):: nn_sum_str

character*200:: filein,filename,fileout1,fileout2
integer i, j, k, cc, cc_p, ifcst, iy, im, id, ih, d1, d2, dd, ibs


BS: DO ibs=1, nbs ! loop basins



FC: DO ifcst=1,nfcst

    ! initialize arrays
    var_sum=0.0
    nn_sum=0.
    nn_sum_p=0.

    write(lead,'(i3)')fcst(ifcst)
    if(fcst(ifcst)==0)then
        lead='000'
    else if(fcst(ifcst)<100)then
        lead(1:1)='0'
    endif
    !print*,lead

    ! set output files
    fileout1='homedir/vnamep.vs.vnamepw_PDF.f'//lead//'.gdat'
    open(88,file=fileout1,form='unformatted', access='direct', &
            recl=nbin,status='unknown',convert='little_endian')


    fileout2='homedir/vnamep.PDF.f'//lead//'.gdat'
    open(99,file=fileout2,form='unformatted',access='direct',&
            recl=nbinp,status='unknown',convert='little_endian')


YR: DO iy=y1,y2
    dd=0
    write(year,'(i4)')iy


    ! uncomment if using all days in a calendar year
    !if( ((mod(iy,4).eq.0.and.mod(iy,100).ne.0).or.mod(iy,400).eq.0)) then
    !    dall=366
    !else
    !    dall=365
    !endif


        MN:     DO im=m1,m2
            write(mon,'(i2)')im
            if(im<10) mon(1:1)='0'

            if (im==2) then
            if(((mod(iy,4).eq.0.and.mod(iy,100).ne.0).or.mod(iy,400).eq.0)) then
                d2=29
            else
                d2=28
            endif
            endif

            if (im==4 .or. im==6 .or. im==9 .or. im==11) then
                d2=30
            else if (im==1 .or. im==3 .or. im==5 .or. im==7 .or.&
                     im==8 .or.im==10 .or. im==12) then
                d2=31
            endif
            
            if (im.ne.m1)then
                d1=1
            else
                d1=(fcst(nfcst)-fcst(ifcst))/24.+1
            endif

            if (im.eq.m2) d2=d2-fcst(ifcst)/24.


            DY:        DO id=d1,d2
                write(day,'(i2)')id
                if(id<10) day(1:1)='0'

                HH:           DO ih=h1,h2,6
                    write(hour,'(i2)')ih
                    if(ih<10) hour(1:1)='0'

                filename='../../../fv3retro/'//year//mon//day//'00/gfs.'&
                        //year//mon//day//'/00/gfs.t00z.pgrb2.1p00.f'//lead
                filein=filename
                !print*,filein,d1,d2,d2-d1+1
                ! shortnames are tp, pwat and lsm for 
                ! Total precip, precipitable water and land mask, respectively
                ! grib_dump filenmae for detailed info 
                call grib_api_decode(filein,shortnm0,nlon,nlat,nz,alev,&
                    fcst(ifcst)-6,var)
                call grib_api_decode(filein,shortnm1,nlon,nlat,nz,alev,&
                    fcst(ifcst),pw)

                if (dd==0)then
                    call grib_api_decode(filein,shortnm2,nlon,nlat,nz,alev,&
                    fcst(ifcst),ldmask)
                endif
                ! uncomment if unit of output variable is mm/day
                var=var*4 ! convert 6h accumulated precip to daily accumulated precip with unit of mm/day                

                dd=dd+1
                !print*,maxval(pw),minval(pw)
                !print*,maxval(ldmask),minval(ldmask)


                    do j=lat1(ibs),lat2(ibs)
                    do i=lon1(ibs),lon2(ibs)
                        ! total precip vs CWV (0:land, 1:sea)
                        if ( ldmask(i,j).le.1 &
                        .and. var(i,j,1) .ne. dmiss &
                        .and. pw(i,j) .ge. pwmin )then
                            cc=int((pw(i,j)-pwmin)/step)+1
                            if(cc>nbin)then
                                    !print*,pw(i,j)
                                    cc=nbin
                            endif
                            var_sum(cc)=var_sum(cc)+var(i,j,1)
                            nn_sum(cc)=nn_sum(cc)+1
                        endif

                        ! PDF of total precip
                        if ( ldmask(i,j).le.1 &
                        .and. var(i,j,1).ne.dmiss)then
                            cc_p=int((var(i,j,1)-pmin)/pstep)+1
                            if(cc_p>nbinp)then
                                print*,var(i,j,1)
                                cc_p=nbinp
                            endif
                            nn_sum_p(cc_p)=nn_sum_p(cc_p)+1
                        endif

                    enddo
                    enddo




                ENDDO HH
            ENDDO DY
        ENDDO MN


ENDDO YR

!print*,dd
!print*,tmax

!-------PDF normalization-----
do cc=1,nbin
    var_str(cc)=var_sum(cc)/nn_sum(cc)
enddo
print*,maxval(var_str),minval(var_str)

do cc=1,nbinp
    nn_sum_str(cc)=nn_sum_p(cc)/sum(nn_sum_p)
enddo

! output
write(88,rec=1) var_str
write(99,rec=1) nn_sum_str


ENDDO FC
ENDDO BS
END
