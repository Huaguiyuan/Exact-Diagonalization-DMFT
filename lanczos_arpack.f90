!+-------------------------------------------------------------------+
!PURPOSE: This routine use ARPACK to find a few eigenvalues
!    LAMBDA and corresponding eigenvectors X for the standard
!    eigenvalue problem:
!      A * X = LAMBDA * X
!    where A is an N by N real symmetric matrix.
!    Storage:
!    The maximum dimensions for all arrays are set here to accommodate 
!    a problem size of NS=N <= MAXN
!    NEV=NEIGEN is the number of eigenvalues requested.
!    See specifications for ARPACK usage below.
!    NCV is the largest number of basis vectors that will be used in 
!    the Implicitly Restarted Arnoldi Process.  Work per major iteration is
!    proportional to N*NCV*NCV.
!    MORE DETAILS ABOUT THE DRIVER ARE GIVEN BELOW:
!+-------------------------------------------------------------------+
subroutine lanczos_arpack_d(ns,neigen,nblock,nitermax,eval,evec,hprod,iverbose)
  implicit none
  !Arguments
  integer             :: ns,neigen,nblock,nitermax
  real(8)             :: eval(neigen),evec(ns,neigen)
  logical,optional    :: iverbose
  !Dimensions:
  integer             :: maxn,maxnev,maxncv,ldv
  integer             :: n,nconv,ncv,nev
  !Arrays:
  real(8),allocatable :: ax(:),d(:,:)
  real(8),allocatable :: resid(:)
  real(8),allocatable :: workl(:),workd(:)
  real(8),allocatable :: v(:,:)
  logical,allocatable :: select(:)
  integer             :: iparam(11)
  integer             :: ipntr(11)
  !Control Vars:
  integer             :: ido,ierr,info,ishfts,j,lworkl,maxitr,mode1
  logical             :: rvec,verb
  integer             :: i
  real(8)             :: sigma
  real(8)             :: tol
  character           :: bmat  
  character(len=2)    :: which
  real(8),external    :: dnrm2
  !Interface to Matrix-Vector routine:
  interface
     subroutine hprod(n,nloc,vin,vout)
       integer                 :: n,nloc
       real(8),dimension(nloc) :: vin,vout
     end subroutine hprod
  end interface

  verb=.false.;if(present(iverbose))verb=iverbose

  !=========================================================================
  !  Specifications for ARPACK usage are set below:
  !  0) N   = Ns set the dimension of the problem
  !  1) NEV = Neigen asks for 4 eigenvalues to be computed.
  !  2) NCV = Nblock sets the length of the Arnoldi factorization.
  !  3) This is a standard problem(indicated by bmat  = 'I')
  !  4) Ask for the NEV eigenvalues of largest magnitude LM, SM, LA, SA, LI, SI.
  !     N,NEV and NCV must satisfy the following conditions:
  !                 N <= MAXN
  !               NEV <= MAXNEV
  !    NEV + 1 <= NCV <= MAXNCV
  maxn   = Ns
  maxnev = Neigen
  maxncv = max(Nblock,5*Neigen+10)
  ldv    = maxn
  if(maxncv>Ns)maxncv=Ns
  !
  n      = maxn
  nev    = maxnev
  ncv    = maxncv
  bmat   = 'I'
  which  = 'SA'
  maxitr = Nitermax
  ! 
  allocate(ax(n))
  allocate(d(ncv,2))
  allocate(resid(n))
  allocate(workl(ncv*(ncv+8)))
  allocate(workd(3*n))
  allocate(v(ldv,ncv))
  allocate(select(ncv))
  !
  ax     =0.d0
  d      =0.d0
  resid  =0.d0
  workl  =0.d0
  workd  =0.d0
  v      =0.d0
  select =0.d0

  !=========================================================================
  !  Specification of stopping rules and initial
  !  conditions before calling SSAUPD
  !  * TOL determines the stopping criterion.  Expect
  !    abs(lambdaC - lambdaT) < TOL*abs(lambdaC)
  !  computed   true
  !  If TOL <= 0, then TOL <- macheps (machine precision) is used.
  !  * IDO is the REVERSE COMMUNICATION parameter
  !  used to specify actions to be taken on return
  !  from SSAUPD. (See usage below.)
  !  It MUST initially be set to 0 before the first
  !  call to SSAUPD.
  !  * INFO on entry specifies starting vector information
  !  and on return indicates error codes
  !  Initially, setting INFO=0 indicates that a
  !  random starting vector is requested to 
  !  start the ARNOLDI iteration.  Setting INFO to
  !  a nonzero value on the initial call is used 
  !  if you want to specify your own starting 
  !  vector. (This vector must be placed in RESID.)
  !  * The work array WORKL is used in SSAUPD as workspace.  Its dimension
  !  LWORKL is set as illustrated below. 
  lworkl = ncv*(ncv+8)
  tol    = 0.d0
  info   = 1
  ido    = 0

  !=========================================================================
  !  Specification of Algorithm Mode:
  !  This program uses the exact shift strategy
  !  (indicated by setting PARAM(1) = 1).
  !  IPARAM(3) specifies the maximum number of Arnoldi iterations allowed.  
  !  Mode 1 of SSAUPD is used (IPARAM(7) = 1). 
  !  All these options can be changed by the user.  For details see the
  !  documentation in SSAUPD.
  !
  ishfts    = 1
  mode1     = 1
  iparam(1) = ishfts
  iparam(3) = maxitr
  iparam(7) = mode1

  call random_seed(put=[1234567])
  call random_number(resid)
  resid=resid/sqrt(dot_product(resid,resid))

  !=========================================================================
  !  MAIN LOOP (Reverse communication loop)
  !  Repeatedly call SSAUPD and take actions indicated by parameter 
  !  IDO until convergence is indicated or MAXITR is exceeded.
  !
  do
     call dsaupd(ido,bmat,n,which,nev,tol,resid,ncv,v,ldv,&
          iparam,ipntr,workd,workl,lworkl,info)
     if(ido/=-1.AND.ido/=1)then
        exit
     end if
     !  Perform matrix vector multiplication
     !    y <--- OP*x ; workd(ipntr(1))=input, workd(ipntr(2))=output
     call hprod(1,n,workd(ipntr(1)),workd(ipntr(2)) )
  end do

  !=========================================================================
  !  Post-Process using SSEUPD.
  if(info<0)then
     write(*,'(a,i6)')'Error with SSAUPD, INFO = ', info
  else
     !  Computed eigenvalues may be extracted.
     !  Eigenvectors may be also computed now if
     !  desired.  (indicated by rvec = .true.)
     !  The routine SSEUPD now called to do this
     !  post processing (Other modes may require
     !  more complicated post processing than mode1.)
     rvec = .true.
     call dseupd(rvec,'All',select,d,v,ldv,sigma,bmat,n,which,&
          nev,tol,resid,ncv,v,ldv,iparam,ipntr,workd,workl,lworkl,ierr)
     !  Eigenvalues are returned in the first column of the two dimensional 
     !  array D and the corresponding eigenvectors are returned in the first 
     !  NCONV (=IPARAM(5)) columns of the two dimensional array V if requested.
     !  Otherwise, an orthogonal basis for the invariant subspace corresponding 
     !  to the eigenvalues in D is returned in V.
     do j=1,neigen
        eval(j)=d(j,1)
        do i=1,ns
           evec(i,j)=v(i,j)
        enddo
     enddo

     !=========================================================================
     !  Compute the residual norm
     !    ||  A*x - lambda*x ||
     !  for the NCONV accurately computed eigenvalues and 
     !  eigenvectors.  (iparam(5) indicates how many are 
     !  accurate to the requested tolerance)
     if(ierr/=0)then
        write(*,'(a,i6)')'Error with SSEUPD, IERR = ',ierr
        write(*,'(a)')'Check the documentation of SSEUPD.'
     else
        nconv =  iparam(5)
        do j = 1, nconv
           call hprod(1, n, v(1,j), ax )
           call daxpy( n, -d(j,1), v(1,j), 1, ax, 1 )
           d(j,2) = dnrm2(n,ax,1)
           d(j,2) = d(j,2) / abs ( d(j,1) )
        end do
        if(verb)call dmout(6,nconv,2,d,maxncv,-6,'Ritz values and relative residuals')
     end if

     if(info==1) then
        write(*,'(a)' ) ' '
        write(*,'(a)' ) '  Maximum number of iterations reached.'
     elseif(info==3) then
        write(*,'(a)' ) ' '
        write(*,'(a)' ) '  No shifts could be applied during implicit '&
             //'Arnoldi update, try increasing NCV.'
     end if

     if(verb)then
        write(*,'(a)') ''
        write(*,'(a)') 'ARPACK - SSSIMP:'
        write(*,'(a)') ''
        write(*,'(a,i6)') '  Size of the matrix is ', n
        write(*,'(a,i6)') '  The number of Ritz values requested is ', nev
        write(*,'(a,i6)') &
             '  The number of Arnoldi vectors generated (NCV) is ', ncv
        write(*,'(a)') '  What portion of the spectrum: ' // which
        write(*,'(a,i6)') &
             '  The number of converged Ritz values is ', nconv
        write(*,'(a,i6)') &
             '  The number of Implicit Arnoldi update iterations taken is ', iparam(3)
        write(*,'(a,i6)') '  The number of OP*x is ', iparam(9)
        write(*,'(a,g14.6)') '  The convergence criterion is ', tol
     end if
  endif
  !< DEBUG
  !this term breaks memory, why?
  !deallocate(ax,resid,workd,v,d,workl,select)
  !> DEBUG
end subroutine lanczos_arpack_d






!+-------------------------------------------------------------------+
!PURPOSE: This routine use ARPACK to find a few eigenvalues
!    LAMBDA and corresponding eigenvectors X for the standard
!    eigenvalue problem:
!      A * X = LAMBDA * X
!    where A is an N by N real symmetric matrix.
!    Storage:
!    The maximum dimensions for all arrays are set here to accommodate 
!    a problem size of NS=N <= MAXN
!    NEV=NEIGEN is the number of eigenvalues requested.
!    See specifications for ARPACK usage below.
!    NCV is the largest number of basis vectors that will be used in 
!    the Implicitly Restarted Arnoldi Process.  Work per major iteration is
!    proportional to N*NCV*NCV.
!    MORE DETAILS ABOUT THE DRIVER ARE GIVEN BELOW:
!+-------------------------------------------------------------------+
subroutine lanczos_arpack_c(ns,neigen,nblock,nitermax,eval,evec,hprod,iverbose)
  implicit none
  !Arguments
  integer             :: ns,neigen,nitermax,nblock
  real(8)             :: eval(neigen)
  complex(8)          :: evec(ns,neigen)
  logical,optional    :: iverbose
  !Dimensions:
  integer             :: maxn,maxnev,maxncv,ldv
  integer             :: n,nconv,ncv,nev
  !Arrays:
  complex(8),allocatable :: ax(:),d(:)
  complex(8),allocatable :: v(:,:)
  complex(8),allocatable :: workl(:),workd(:),workev(:)
  complex(8),allocatable :: resid(:)
  real(8),allocatable    :: rwork(:),rd(:,:)
  logical,allocatable    :: select(:)
  integer                :: iparam(11)
  integer                :: ipntr(14)
  !Control Vars:
  integer                :: ido,ierr,info,ishfts,j,lworkl,maxitr,mode1
  logical                :: rvec,verb
  integer                :: i
  real(8)                :: sigma
  real(8)                :: tol
  character              :: bmat  
  character(len=2)       :: which
  real(8),external       :: dznrm2,dlapy2
  real(8),allocatable    :: reV(:),imV(:)

  !Interface to Matrix-Vector routine:
  interface
     subroutine hprod(n,nloc,vin,vout)
       integer                    :: n,nloc
       complex(8),dimension(nloc) :: vin,vout
     end subroutine hprod
  end interface

  verb=.false.;if(present(iverbose))verb=iverbose

  !=========================================================================
  !  Specifications for ARPACK usage are set below:
  !  0) N   = Ns set the dimension of the problem
  !  1) NEV = Neigen asks for 4 eigenvalues to be computed.
  !  2) NCV = Nblock sets the length of the Arnoldi factorization.
  !  3) This is a standard problem(indicated by bmat  = 'I')
  !  4) Ask for the NEV eigenvalues of largest magnitude LM, SM, LA, SA, LI, SI.
  !     N,NEV and NCV must satisfy the following conditions:
  !                 N <= MAXN
  !               NEV <= MAXNEV
  !    NEV + 1 <= NCV <= MAXNCV
  maxn   = Ns
  maxnev = Neigen
  maxncv = min(nblock,5*Neigen+10)
  ldv    = maxn
  if(maxncv>Ns)maxncv=Ns
  !
  n      = maxn
  nev    = maxnev
  ncv    = maxncv
  bmat   = 'I'
  which  = 'SR'
  maxitr = Nitermax

  !=========================================================================
  !  Specification of stopping rules and initial
  !  conditions before calling SSAUPD
  !  * TOL determines the stopping criterion.  Expect
  !    abs(lambdaC - lambdaT) < TOL*abs(lambdaC)
  !  computed   true
  !  If TOL <= 0, then TOL <- macheps (machine precision) is used.
  !  * IDO is the REVERSE COMMUNICATION parameter
  !  used to specify actions to be taken on return
  !  from SSAUPD. (See usage below.)
  !  It MUST initially be set to 0 before the first
  !  call to SSAUPD.
  !  * INFO on entry specifies starting vector information
  !  and on return indicates error codes
  !  Initially, setting INFO=0 indicates that a
  !  random starting vector is requested to 
  !  start the ARNOLDI iteration.  Setting INFO to
  !  a nonzero value on the initial call is used 
  !  if you want to specify your own starting 
  !  vector. (This vector must be placed in RESID.)
  !  * The work array WORKL is used in SSAUPD as workspace.  Its dimension
  !  LWORKL is set as illustrated below. 
  lworkl = ncv*(3*ncv+5) + 10
  tol    = 0.0 
  ido    = 0
  info   = 1


  allocate(ax(n))
  allocate(d(ncv))
  allocate(resid(n))
  allocate(v(ldv,ncv))
  allocate(workd(3*n))
  allocate(workev(3*ncv))
  allocate(workl(lworkl))
  allocate(rwork(ncv))
  allocate(rd(ncv,3))
  allocate(select(ncv))

  ax     = zero
  d      = zero
  v      = zero
  workl  = zero
  workd  = zero
  resid  = zero
  workev = zero
  rwork  = 0.d0
  rd     = 0.d0

  !=========================================================================
  !  Specification of Algorithm Mode:
  !  This program uses the exact shift strategy
  !  (indicated by setting PARAM(1) = 1).
  !  IPARAM(3) specifies the maximum number of Arnoldi iterations allowed.  
  !  Mode 1 of SSAUPD is used (IPARAM(7) = 1). 
  !  All these options can be changed by the user.  For details see the
  !  documentation in SSAUPD.
  !
  ishfts    = 1
  mode1     = 1
  iparam(1) = ishfts
  iparam(3) = maxitr
  iparam(7) = mode1



  call random_seed(put=[1234567])
  allocate(reV(size(resid)),imV(size(resid)))
  call random_number(reV)
  call random_number(imV)
  resid=dcmplx(reV,imV)
  deallocate(reV,imV)
  resid=resid/sqrt(dot_product(resid,resid))


  !=========================================================================
  !  MAIN LOOP (Reverse communication loop)
  !  Repeatedly call SSAUPD and take actions indicated by parameter 
  !  IDO until convergence is indicated or MAXITR is exceeded.
  !
  do
     call znaupd(ido,bmat,n,which,nev,tol,resid,ncv,v,ldv,&
          iparam,ipntr,workd,workl,lworkl,rwork,info)
     if(ido/=-1.AND.ido/=1)then
        exit
     end if
     !  Perform matrix vector multiplication
     !    y <--- OP*x ; workd(ipntr(1))=input, workd(ipntr(2))=output
     call hprod(1,n,workd(ipntr(1)),workd(ipntr(2)) )
  end do

  !=========================================================================
  !  Post-Process using SSEUPD.
  if(info<0)then
     write(*,'(a)')'SSSIMP - Fatal error!'
     write(*,'(a,i6)')'Error with ZNAUPD, INFO = ', info
  else
     !  Computed eigenvalues may be extracted.
     !  Eigenvectors may be also computed now if
     !  desired.  (indicated by rvec = .true.)
     !  The routine ZNEUPD now called to do this
     !  post processing (Other modes may require
     !  more complicated post processing than mode1.)
     rvec = .true.
     call zneupd  (rvec,'A',select,d,v,ldv,sigma,workev,bmat,n,which,&
          nev,tol,resid,ncv,v,ldv,iparam,ipntr,workd,workl,lworkl,rwork,ierr)
     !  Eigenvalues are returned in the first column of the two dimensional 
     !  array D and the corresponding eigenvectors are returned in the first 
     !  NCONV (=IPARAM(5)) columns of the two dimensional array V if requested.
     !  Otherwise, an orthogonal basis for the invariant subspace corresponding 
     !  to the eigenvalues in D is returned in V.
     do j=1,neigen
        eval(j)=d(j)
        do i=1,ns
           evec(i,j)=v(i,j)
        enddo
     enddo

     !=========================================================================
     !  Compute the residual norm
     !    ||  A*x - lambda*x ||
     !  for the NCONV accurately computed eigenvalues and 
     !  eigenvectors.  (iparam(5) indicates how many are 
     !  accurate to the requested tolerance)
     if(ierr/=0)then
        write(*,'(a,i6)')'Error with SSEUPD, IERR = ',ierr
        write(*,'(a)')'Check the documentation of SSEUPD.'
     else
        nconv =  iparam(5)
        do j = 1, nconv
           call hprod(1, n, v(1,j), ax )
           call zaxpy( n, -d(j), v(1,j), 1, ax, 1 )
           rd(j,1) = dble (d(j))
           rd(j,2) = dimag (d(j))
           rd(j,3) = dznrm2 (n, ax, 1)
           rd(j,3) = rd(j,3) / dlapy2 (rd(j,1),rd(j,2))
        end do
        if(verb)call dmout(6,nconv,3,rd,maxncv,-6,'Ritz values and relative residuals')
     end if
     if(info==1) then
        write(*,'(a)' ) ' '
        write(*,'(a)' ) '  Maximum number of iterations reached.'
     elseif(info==3) then
        write(*,'(a)' ) ' '
        write(*,'(a)' ) '  No shifts could be applied during implicit '&
             //'Arnoldi update, try increasing NCV.'
     end if

     if(verb)then
        write(*,'(a)') ''
        write(*,'(a)') 'ARPACK - SSSIMP:'
        write(*,'(a)') ''
        write(*,'(a,i6)') '  Size of the matrix is ', n
        write(*,'(a,i6)') '  The number of Ritz values requested is ', nev
        write(*,'(a,i6)') &
             '  The number of Arnoldi vectors generated (NCV) is ', ncv
        write(*,'(a)') '  What portion of the spectrum: ' // which
        write(*,'(a,i6)') &
             '  The number of converged Ritz values is ', nconv
        write(*,'(a,i6)') &
             '  The number of Implicit Arnoldi update iterations taken is ', iparam(3)
        write(*,'(a,i6)') '  The number of OP*x is ', iparam(9)
        write(*,'(a,g14.6)') '  The convergence criterion is ', tol
     end if
  endif
end subroutine lanczos_arpack_c
