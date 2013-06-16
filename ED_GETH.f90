!########################################################################
!PURPOSE  : Build the impurity Hamiltonian
!|ImpUP,(2ImpUP),BathUP;,ImpDW,(2ImpDW),BathDW >
! |1,2;3...Ns>_UP * |Ns+1,Ns+2;Ns+3,...,2*Ns>_DOWN
!########################################################################
MODULE ED_GETH
  USE ED_VARS_GLOBAL
  USE ED_BATH
  USE ED_AUX_FUNX
  implicit none
  private
  public :: full_ed_geth
  public :: lanc_ed_geth
  public :: HtimesV,spHtimesV
  public :: set_Hsector

  integer :: Hsector

contains

  !+------------------------------------------------------------------+
  !PURPOSE  : 
  !+------------------------------------------------------------------+
  subroutine full_ed_geth(isector,h)
    real(8)                  :: h(:,:)
    integer                  :: ib(Ntot)
    integer                  :: dim
    integer                  :: i,j,k,r,m,ms
    integer                  :: kp,isector
    real(8),dimension(Nbath) :: eup,edw,vup,vdw
    real(8)                  :: ndup,nddw,npup,npdw,nup,ndw,sg1,sg2,tef

    dim=getdim(isector)
    if(size(h,1)/=dim)call error("FULL_ED_GETH: wrong dimension 1 of H")
    if(size(h,2)/=dim)call error("FULL_ED_GETH: wrong dimension 2 of H")

    h=0.d0

    eup=ebath(1,:)
    vup=vbath(1,:)
    edw=eup
    vdw=vup
    if(Nspin==2)then
       edw=ebath(2,:)
       vdw=vbath(2,:)
    endif

    do i=1,dim
       m=Hmap(isector)%map(i)
       call bdecomp(m,ib)

       if(Norb==1)then
          nup=real(ib(1),8) ; ndw=real(ib(1+Ns),8)
          select case(hfmode)
          case(.true.)
             h(i,i)=-xmu*(nup+ndw) + u*(nup-0.5d0)*(ndw-0.5d0) + heff*(nup-ndw)
          case (.false.)
             h(i,i)=-xmu*(nup+ndw) + u*nup*ndw + heff*(nup-ndw)
          end select

          do kp=2,Ns
             h(i,i)=h(i,i)+eup(kp-1)*real(ib(kp),8)
             h(i,i)=h(i,i)+edw(kp-1)*real(ib(kp+Ns),8)
          enddo

          !NON-Diagonal part
          do ms=2,Ns
             if(ib(1) == 1 .AND. ib(ms) == 0)then
                call c(1,m,k);sg1=dfloat(k)/dfloat(abs(k));k=abs(k)
                call cdg(ms,k,r);sg2=dfloat(r)/dfloat(abs(r));r=abs(r)
                j=invHmap(isector,r)
                tef=vup(ms-1)
                h(i,j)=tef*sg1*sg2
                h(j,i)=h(i,j)!Hermitian conjugate 
             endif
             if(ib(1+Ns) == 1 .AND. ib(ms+Ns) == 0)then
                call c(1+Ns,m,k);sg1=dfloat(k)/dfloat(abs(k));k=abs(k)
                call cdg(ms+Ns,k,r);sg2=dfloat(r)/dfloat(abs(r));r=abs(r)           
                j=invHmap(isector,r)
                tef=vdw(ms-1)   
                h(i,j)=tef*sg1*sg2
                h(j,i)=h(i,j)
             endif
          enddo

       elseif(Norb==2)then
          ndup=dble(ib(1)) ; nddw=dble(ib(1+Ns))
          npup=dble(ib(2)) ; npdw=dble(ib(2+Ns))
          h(i,i)= -xmu*(ndup+nddw) + u*(ndup-0.5d0)*(nddw-0.5d0) + heff*(ndup-nddw) &
               + (-xmu+ep0)*(npup+npdw) + heff*(npup-npdw)
          do kp=3,Ns
             h(i,i)=h(i,i)+eup(kp-2)*real(ib(kp),8)
             h(i,i)=h(i,i)+edw(kp-2)*real(ib(kp+Ns),8)
          enddo
          !NON-Diagonal part       
          !UP-SPIN PART
          do ms=3,Ns
             if(ib(2) == 1 .AND. ib(ms) == 0)then
                call c(2,m,k);sg1=dfloat(k)/dfloat(abs(k));k=abs(k)
                call cdg(ms,k,r);sg2=dfloat(r)/dfloat(abs(r));r=abs(r)
                j=invHmap(isector,r)
                tef=vup(ms-2)
                h(i,j)=tef*sg1*sg2
                h(j,i)=h(i,j)!Hermitian conjugate 
             endif
          enddo
          !DW-SPIN PART
          do ms=3,Ns
             if(ib(2+Ns) == 1 .AND. ib(ms+Ns) == 0)then
                call c(Norb+Ns,m,k);sg1=dfloat(k)/dfloat(abs(k));k=abs(k)
                call cdg(ms+Ns,k,r);sg2=dfloat(r)/dfloat(abs(r));r=abs(r)
                j=invHmap(isector,r)
                tef=vdw(ms-2)   
                h(i,j)=tef*sg1*sg2
                h(j,i)=h(i,j)
             endif
          enddo
          !Hybridization part
          if(ib(1) == 1 .AND. ib(2) == 0)then
             call c(1,m,k);sg1=dfloat(k)/dfloat(abs(k));k=abs(k)
             call cdg(2,k,r);sg2=dfloat(r)/dfloat(abs(r));r=abs(r)
             j=invHmap(isector,r)
             tef=tpd
             h(i,j)=tef*sg1*sg2
             h(j,i)=h(i,j)
          endif
          if(ib(1+Ns) == 1 .AND. ib(2+Ns) == 0)then
             call c(1+Ns,m,k);sg1=dfloat(k)/dfloat(abs(k));k=abs(k)
             call cdg(2+Ns,k,r);sg2=dfloat(r)/dfloat(abs(r));r=abs(r)
             j=invHmap(isector,r)
             tef=tpd
             h(i,j)=tef*sg1*sg2
             h(j,i)=h(i,j)
          endif
       endif
    enddo
    return
  end subroutine fulled_ed_geth


  !*********************************************************************
  !*********************************************************************
  !*********************************************************************



  !+------------------------------------------------------------------+
  !PURPOSE  : 
  !+------------------------------------------------------------------+
  subroutine lanc_ed_geth(isector)
    integer                  :: isector
    integer                  :: ib(Ntot)
    integer                  :: dim
    integer                  :: i,j,k,r,m,ms,ispin
    integer                  :: kp
    integer                  :: iimp,ibath
    real(8),dimension(Nbath) :: eup,edw,vup,vdw
    real(8)                  :: ndup,nddw,npup,npdw,nup,ndw,sg1,sg2,tef,htmp

    dim=getdim(isector)
    if(.not.spH0%status)call error("LANC_ED_GETH: spH0 not initialized at sector:"//txtfy(isector))

    eup=ebath(1,:)
    vup=vbath(1,:)
    edw=eup
    vdw=vup
    if(Nspin==2)then
       edw=ebath(2,:)
       vdw=vbath(2,:)
    endif

    do i=1,dim
       m=Hmap(isector)%map(i)!Hmap(isector,i)
       call bdecomp(m,ib)

       if(Norb==1)then
          nup=real(ib(1),8)
          ndw=real(ib(1+Ns),8)
          !Diagonal part
          !local part of the impurity Hamiltonian: (-mu+\e0)*n + U*(n_up-0.5)*(n_dw-0.5) + heff*mag
          !+ energy of the bath=\sum_{n=1,N}\e_l n_l
          htmp=0.d0
          select case(hfmode)
          case(.true.)
             htmp = -xmu*(nup+ndw) + U*(nup-0.5d0)*(ndw-0.5d0) + heff*(nup-ndw)
          case (.false.)
             htmp = -(xmu+U/2d0)*(nup+ndw) + U*nup*ndw + heff*(nup-ndw)
          end select
          !energy of the bath=\sum_{n=1,N}\e_l n_l
          do kp=2,Ns
             htmp=htmp + eup(kp-1)*real(ib(kp),8)
             htmp=htmp + edw(kp-1)*real(ib(kp+Ns),8)
          enddo
          call sp_insert_element(spH0,htmp,i,i)
          !Non-Diagonal part
          do ms=2,Ns
             if(ib(1)==1 .AND. ib(ms)==0)then
                call c(1,m,k);sg1=dfloat(k)/dfloat(abs(k));k=abs(k)
                call cdg(ms,k,r);sg2=dfloat(r)/dfloat(abs(r));r=abs(r)
                j=invHmap(isector,r)
                tef=vup(ms-1)
                htmp = tef*sg1*sg2
                !
                call sp_insert_element(spH0,htmp,i,j)
                call sp_insert_element(spH0,htmp,j,i)
             endif
             if(ib(1+Ns)==1 .AND. ib(ms+Ns)==0)then
                call c(1+Ns,m,k);sg1=dfloat(k)/dfloat(abs(k));k=abs(k)
                call cdg(ms+Ns,k,r);sg2=dfloat(r)/dfloat(abs(r));r=abs(r)           
                j=invHmap(isector,r)
                tef=vdw(ms-1)   
                htmp=tef*sg1*sg2
                call sp_insert_element(spH0,htmp,i,j)
                call sp_insert_element(spH0,htmp,j,i)
             endif
          enddo

       elseif(Norb==2)then
          ndup=dble(ib(1)) 
          nddw=dble(ib(1+Ns))
          npup=dble(ib(2))
          npdw=dble(ib(2+Ns))
          htmp=0.d0
          select case(hfmode)
          case(.true.)
             htmp = -xmu*(ndup+nddw) + u*(ndup-0.5d0)*(nddw-0.5d0) + heff*(ndup-nddw) &
                  + (-xmu+ep0)*(npup+npdw) + heff*(npup-npdw)
          case(.false.)
             htmp = -xmu*(ndup+nddw) + u*ndup*nddw + heff*(ndup-nddw) &
                  + (-xmu+ep0)*(npup+npdw) + heff*(npup-npdw)
          end select
          !bath:
          do kp=3,Ns
             htmp=htmp+eup(kp-2)*real(ib(kp),8)
             htmp=htmp+edw(kp-2)*real(ib(kp+Ns),8)
          enddo

          call sp_insert_element(spH0,htmp,i,i)


          !NON-Diagonal part       
          !UP-SPIN PART
          do ms=3,Ns
             if(ib(2) == 1 .AND. ib(ms) == 0)then
                call c(2,m,k);sg1=dfloat(k)/dfloat(abs(k));k=abs(k)
                call cdg(ms,k,r);sg2=dfloat(r)/dfloat(abs(r));r=abs(r)
                j=invnmap(isloop,r)
                tef=vup(ms-2)
                htmp=tef*sg1*sg2
                call sp_insert_element(spH0,htmp,i,j)
                call sp_insert_element(spH0,htmp,j,i)
             endif
          enddo
          !DW-SPIN PART
          do ms=3,Ns
             if(ib(2+Ns) == 1 .AND. ib(ms+Ns) == 0)then
                call c(2+Ns,m,k);sg1=dfloat(k)/dfloat(abs(k));k=abs(k)
                call cdg(ms+Ns,k,r);sg2=dfloat(r)/dfloat(abs(r));r=abs(r)
                j=invnmap(isloop,r)
                tef=vdw(ms-2)   
                htmp=tef*sg1*sg2
                call sp_insert_element(spH0,htmp,i,j)
                call sp_insert_element(spH0,htmp,j,i)
             endif
          enddo
          !Hybridization part
          if(ib(1) == 1 .AND. ib(2) == 0)then
             call c(1,m,k);sg1=dfloat(k)/dfloat(abs(k));k=abs(k)
             call cdg(2,k,r);sg2=dfloat(r)/dfloat(abs(r));r=abs(r)
             j=invnmap(isloop,r)
             tef=tpd
             htmp=tef*sg1*sg2
             call sp_insert_element(spH0,htmp,i,j)
             call sp_insert_element(spH0,htmp,j,i)
          endif
          if(ib(1+Ns) == 1 .AND. ib(2+Ns) == 0)then
             call c(1+Ns,m,k);sg1=dfloat(k)/dfloat(abs(k));k=abs(k)
             call cdg(2+Ns,k,r);sg2=dfloat(r)/dfloat(abs(r));r=abs(r)
             j=invnmap(isloop,r)
             tef=tpd
             htmp=tef*sg1*sg2
             call sp_insert_element(spH0,htmp,i,j)
             call sp_insert_element(spH0,htmp,j,i)
          endif
       endif
    enddo
    return
  end subroutine lanc_ed_geth


  !*********************************************************************
  !*********************************************************************
  !*********************************************************************


  subroutine  set_Hsector(isector)
    integer :: isector
    Hsector=isector
  end subroutine set_Hsector


  subroutine spHtimesV(N,v,Hv)
    integer              :: N
    real(8),dimension(N) :: v
    real(8),dimension(N) :: Hv
    Hv=zero
    call sp_matrix_vector_product(N,spH0,v,Hv)
  end subroutine SpHtimesV



  ! subroutine HtimesV(Nv,v,Hv)
  !   integer                  :: Nv
  !   real(8),dimension(Nv)    :: v
  !   real(8),dimension(Nv)    :: Hv
  !   integer                  :: isector
  !   integer                  :: ib(Ntot)
  !   integer                  :: dim
  !   integer                  :: i,j,k,r,m,ms,ispin
  !   integer                  :: kp
  !   integer                  :: iimp,ibath
  !   real(8),dimension(Nbath) :: eup,edw,vup,vdw
  !   real(8)                  :: ndup,nddw,npup,npdw,nup,ndw,sg1,sg2,tef,htmp

  !   isector=Hsector
  !   dim=getdim(isector)
  !   eup=ebath(1,:)
  !   vup=vbath(1,:)
  !   edw=eup
  !   vdw=vup
  !   if(Nspin==2)then
  !      edw=ebath(2,:)
  !      vdw=vbath(2,:)
  !   endif

  !   if(Nv/=dim)call error("HtimesV error in dimensions")
  !   Hv=0.d0

  !   do i=1,dim
  !      m=Hmap(isector)%map(i)
  !      call bdecomp(m,ib)
  !      nup=real(ib(1),8)
  !      ndw=real(ib(1+Ns),8)

  !      !Diagonal part
  !      !local part of the impurity Hamiltonian: (-mu+\e0)*n + U*(n_up-0.5)*(n_dw-0.5) + heff*mag
  !      !+ energy of the bath=\sum_{n=1,N}\e_l n_l
  !      htmp=0.d0
  !      select case(hfmode)
  !      case(.true.)
  !         htmp = -xmu*(nup+ndw) + U*(nup-0.5d0)*(ndw-0.5d0) + heff*(nup-ndw)
  !      case (.false.)
  !         htmp = -(xmu+U/2d0)*(nup+ndw) + U*nup*ndw + heff*(nup-ndw)
  !      end select
  !      !energy of the bath=\sum_{n=1,N}\e_l n_l
  !      do kp=2,Ns
  !         htmp=htmp + eup(kp-1)*real(ib(kp),8)
  !         htmp=htmp + edw(kp-1)*real(ib(kp+Ns),8)
  !      enddo

  !      Hv(i) = Hv(i) + htmp*v(i)

  !      !Non-Diagonal part
  !      do ms=2,Ns
  !         if(ib(1)==1 .AND. ib(ms)==0)then
  !            call c(1,m,k);sg1=dfloat(k)/dfloat(abs(k));k=abs(k)
  !            call cdg(ms,k,r);sg2=dfloat(r)/dfloat(abs(r));r=abs(r)
  !            j=invHmap(isector,r)
  !            tef=vup(ms-1)
  !            htmp = tef*sg1*sg2
  !            Hv(i) = Hv(i) + htmp*v(j)
  !            Hv(j) = Hv(j) + htmp*v(i)
  !         endif
  !         if(ib(1+Ns)==1 .AND. ib(ms+Ns)==0)then
  !            call c(1+Ns,m,k);sg1=dfloat(k)/dfloat(abs(k));k=abs(k)
  !            call cdg(ms+Ns,k,r);sg2=dfloat(r)/dfloat(abs(r));r=abs(r)           
  !            j=invHmap(isector,r)
  !            tef=vdw(ms-1)   
  !            htmp=tef*sg1*sg2
  !            Hv(i) = Hv(i) + htmp*v(j)
  !            Hv(j) = Hv(j) + htmp*v(i)
  !         endif
  !      enddo
  !   enddo
  !   return
  ! end subroutine HtimesV


end MODULE ED_GETH
