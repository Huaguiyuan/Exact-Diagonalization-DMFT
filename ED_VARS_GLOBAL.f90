MODULE ED_VARS_GLOBAL
  USE COMMON_VARS
  USE SCIFOR_VERSION
  USE TIMER
  USE PARSE_CMD
  USE IOTOOLS
  USE MATRIX, only: matrix_diagonalize
  USE OPTIMIZE
  USE TOOLS, only: arange,linspace
  !
  USE EIGEN_SPACE
  USE PLAIN_LANCZOS
  !USE ARPACK_LANCZOS
  !USE MATRIX_SPARSE
  implicit none

  !GIT VERSION
  include "revision.inc"

  !SIZE OF THE PROBLEM (as PARAMETERS to allocate in the stack)
  !VARIABLES and DEFINITIONS in common to every subroutine
  !Ns=numero di siti del sistema (ogni sito puo' contenere 2e^-)
  !N=2*Ns=numero totale di particelle
  !Lo spazio di Hilbert e' dato dal prodotto tensore 2^Ns * 2^Ns=2^N =NN (LARGE)
  !Nbath=Ns-1=numero di siti del bagno (sistema - impurezza)
  !NP=dimensione del sottospazio piu' grande (settore).
  !=========================================================
  integer :: Ns,Nimp,Nspin,Nbath,NP,N,NN,Nsect


  !Global variables
  !=========================================================
  integer :: nloop          !max dmft loop variables
  real(8) :: u              !local,non-local interaction
  real(8) :: xmu            !chemical potential
  real(8) :: beta           !inverse temperature
  real(8) :: eps            !broadening
  real(8) :: wini,wfin      !
  integer :: Nsuccess       !
  real(8) :: weight         !
  real(8) :: heff           !
  logical :: chiflag        !
  logical :: HFmode         !flag for HF interaction form U(n-1/2)(n-1/2) VS Unn
  real(8) :: cutoff         !cutoff for spectral summation
  real(8) :: eps_error      !
  integer :: nGFitermax     !Max number of iteration in resolvant tri-diagonalization
  integer :: cgNitmax       !Max number of iteration in the fit
  real(8) :: cgFtol         !Tolerance in the cg fit
  integer :: cgType         !CGfit mode 0=normal,1=1/n weight, 2=1/w weight

  !Dimension of the functions:
  !=========================================================
  integer :: NL,Ltau,Nw,Nfit



  !Some maps between sectors and full Hilbert space (pointers)
  !=========================================================
  integer,allocatable,dimension(:,:) :: Hmap,invHmap
  integer,allocatable,dimension(:,:) :: getsector
  integer,allocatable,dimension(:)   :: getCUPsector,getCDWsector
  integer,allocatable,dimension(:)   :: getCDGUPsector,getCDGDWsector
  integer,allocatable,dimension(:)   :: getdim,getin,getis
  integer                            :: startloop,lastloop


  !Eigenvalues,Eigenvectors 
  !=========================================================
  type(eigenspace),dimension(:),allocatable :: espace


  !Ground state variables
  !=========================================================
  integer                                 :: numzero
  integer,dimension(:),allocatable        :: iszero
  ! type gstate
  !    real(8)                            :: egs
  !    real(8),dimension(:),pointer       :: vec
  ! end type gstate
  ! type(gstate),dimension(:),allocatable :: groundstate
  type(eig_space)                         :: groundstate
  real(8),dimension(:,:),allocatable      :: H0

  !Partition function
  !=========================================================
  real(8) :: zeta_function


  !Functions for GETGFUNX (names must be changed)
  !=========================================================
  complex(8),allocatable,dimension(:,:) :: Giw,Siw
  complex(8),allocatable,dimension(:,:) :: Gwr,Swr
  real(8),allocatable,dimension(:)      :: Chitau
  complex(8),allocatable,dimension(:)   :: Chiw


  !Variables for fixed density mu-loop 
  !=========================================================
  real(8) :: nread,nerr,ndelta

  !Qties needed to get energy
  !=========================================================
  real(8) ::  nsimp,dimp,nupimp,ndwimp,magimp,m2imp


  !NML READ/WRITE UNITS
  character(len=32) :: Hfile,Ofile,GMfile,GRfile,CTfile,CWfile
  integer           :: LOGfile


  !Writing/Reading Units:
  character(len=32) :: USEDinput


  namelist/EDvars/Ns,Nimp,Nspin,&       
       beta,xmu,nloop,u,        &
       eps,wini,wfin,heff,      &
       NL,Nw,Ltau,Nfit,         &
       nread,nerr,ndelta,       &
       chiflag,cutoff,HFmode,   &
       eps_error,Nsuccess,      &
       cgNitmax,cgFtol,cgType,   &
       Hfile,Ofile,GMfile,GRfile,CTfile,CWfile,LOGfile

contains

  !+-------------------------------------------------------------------+
  !PROGRAM  : 
  !TYPE     : subroutine
  !PURPOSE  : 
  !+-------------------------------------------------------------------+
  subroutine read_input(INPUTunit)
    character(len=*) :: INPUTunit
    integer          :: i
    logical          :: control

    !ModelConf
    Ns         = 5
    Nimp       = 1
    Nspin      = 1
    u          = 2.d0
    xmu        = 0.d0
    beta       = 50.d0
    !Loops
    nloop      = 100
    chiflag    =.true.
    hfmode     =.true.
    !parameters
    NL         = 1024
    Nw         = 1024
    Ltau       = 500
    Nfit       = 1024
    eps        = 0.005d0
    nread      = 0.d0
    nerr       = 1.d-4
    ndelta     = 0.1d0
    wini       =-4.d0
    wfin       = 4.d0
    heff       = 0.d0
    cutoff     = 1.d-9
    eps_error  = 1.d-5
    nsuccess   = 2
    nGFitermax = 100
    cgNitmax   = 1000
    cgFtol     = 1.d-9
    cgType     = 0
    !ReadUnits
    Hfile  ="hamiltonian.restart"
    GMfile ="impG_iw.ed"
    GRfile ="impG_realw.ed"
    CTfile ="Chi_tau.ed"
    CWfile ="Chi_realw.ed"    
    Ofile  ="observables.ed"
    LOGfile=6

    inquire(file=INPUTunit,exist=control)    
    if(control)then
       open(50,file=INPUTunit,status='old')
       read(50,nml=EDvars)
       close(50)
    else
       print*,"Can not find INPUT file"
       print*,"Printing a default version in default."//INPUTunit
       open(50,file="default."//INPUTunit)
       write(50,nml=EDvars)
       write(50,*)""
       stop
    endif

    call parse_cmd_variable(Ns,"NS")
    call parse_cmd_variable(Nimp,"NIMP")
    call parse_cmd_variable(Nspin,"NSPIN")
    call parse_cmd_variable(beta,"BETA")
    call parse_cmd_variable(xmu,"XMU")
    call parse_cmd_variable(u,"U")
    call parse_cmd_variable(nloop,"NLOOP")
    call parse_cmd_variable(eps_error,"EPS_ERROR")
    call parse_cmd_variable(nsuccess,"NSUCCESS")
    call parse_cmd_variable(NL,"NL")
    call parse_cmd_variable(Nw,"NW")
    call parse_cmd_variable(Ltau,"LTAU")
    call parse_cmd_variable(Nfit,"NFIT")
    call parse_cmd_variable(nread,"NREAD")
    call parse_cmd_variable(nerr,"NERR")
    call parse_cmd_variable(ndelta,"NDELTA")
    call parse_cmd_variable(wini,"WINI","WMIN")
    call parse_cmd_variable(wfin,"WFIN","WMAX")
    call parse_cmd_variable(chiflag,"CHIFLAG")
    call parse_cmd_variable(hfmode,"HFMODE")
    call parse_cmd_variable(eps,"EPS")
    call parse_cmd_variable(cutoff,"CUTOFF")
    call parse_cmd_variable(heff,"HEFF")
    call parse_cmd_variable(nGFitermax,"NGFITERMAX")
    call parse_cmd_variable(cgNitmax,"CGNITMAX")
    call parse_cmd_variable(cgFtol,"CGFTOL")
    call parse_cmd_variable(cgType,"CGTYPE")
    call parse_cmd_variable(Hfile,"HFILE")
    call parse_cmd_variable(Ofile,"OFILE")
    call parse_cmd_variable(GMfile,"GMFILE")
    call parse_cmd_variable(GRfile,"GRFILE")
    call parse_cmd_variable(CTfile,"CTFILE")
    call parse_cmd_variable(CWfile,"CWFILE")
    call parse_cmd_variable(LOGfile,"LOGFILE")

    call version(revision)

    call allocate_system_structure()

    write(*,*)"CONTROL PARAMETERS"
    write(*,nml=EDvars)
    write(*,*)"--------------------------------------------"
    write(*,*)'| Total number of sites/spin   = ',Ns
    write(*,*)'| Maximum dimension            = ',NP
    write(*,*)'| Number of impurities         = ',Nimp
    write(*,*)'| Bath`s number of sites/spin  = ',Nbath
    write(*,*)'| Total size, Hilber space dim.= ',N,NN
    write(*,*)'| Number of sectors            = ',Nsect
    write(*,*)"--------------------------------------------"
    write(*,*)'| mu       = ',xmu
    write(*,*)'| T        = ',1.d0/beta
    write(*,*)"--------------------------------------------"
    print*,''
    USEDinput="used."//INPUTunit
    open(50,file=trim(adjustl(trim(USEDinput))))
    write(50,nml=EDvars)
    close(50)

    !Some check:
    if(Nfit>NL)Nfit=NL
    if(Nimp>1)call abort("Norb > 1 is not yet supported!")
    if(Ns>8)call abort("Ns > 8 is too big!")
    if(nerr > eps_error) nerr=eps_error

    !allocate functions
    allocate(Giw(Nspin,NL),Siw(Nspin,NL))
    allocate(Gwr(Nspin,Nw),Swr(Nspin,Nw))
    if(chiflag)allocate(Chitau(0:Ltau),Chiw(Nw))

  end subroutine read_input



  !+-------------------------------------------------------------------+
  !PROGRAM  : 
  !TYPE     : subroutine
  !PURPOSE  : 
  !+-------------------------------------------------------------------+
  subroutine allocate_system_structure()
    select case(Ns)
    case (3)
       NP=9
    case (4)
       NP=36
    case (5)
       NP=100
    case (6)
       NP=400
    case (7)
       NP=1225
    case (8)
       NP=4900
    end select
    Nbath = Ns-Nimp
    N     = 2*Ns
    NN    = 2**N
    Nsect = ((Ns+1)*(Ns+1) - 1)
    allocate(Hmap(Nsect,NP),invHmap(Nsect,NN))
    allocate(getdim(Nsect),getin(Nsect),getis(Nsect))
    allocate(getsector(N,-N:N))
    allocate(getCUPsector(Nsect),getCDWsector(Nsect))
    allocate(getCDGUPsector(Nsect),getCDGDWsector(Nsect))
  end subroutine allocate_system_structure



END MODULE ED_VARS_GLOBAL
