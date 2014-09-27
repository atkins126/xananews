// 21/06/2001  Use 'sysutils' version info instead of calling GetVersionInfoEx

unit cmpNTAboutBox;

interface
{$IF CompilerVersion >= 24}   //XE3 - Rad Studio 10.0
  {$LEGACYIFEND ON}
  {$define has_StyleElements}
  {$define HasSystemUITypes}
{$IFEND}
{$IF CompilerVersion >= 23}   //XE2 - Rad Studio 9.0
   {$define UseVCLStyles}
   {$define HasTOSVersion}
{$IFEND}

uses
  Windows, SysUtils, Classes, Graphics, Forms, Controls, StdCtrls,
  Buttons, ExtCtrls, cmpHyperlinkButton, ComCtrls;

type
  TfmNTAboutBox = class(TForm)
    PageControl1: TPageControl;
    TabSheet1: TTabSheet;
    TabSheet2: TTabSheet;
    icoProduct: TImage;
    stProduct: TLabel;
    stVersion: TLabel;
    stCopyright: TLabel;
    lblSupport: TLabel;
    Label1: TLabel;
    stLicense1: TLabel;
    stLicense2: TLabel;
    Bevel1: TBevel;
    stMemAvail: TLabel;
    icoProduct1: TImage;
    OKBtn: TButton;
    hlbSupport: THyperlinkButton;
    stThankYou: TLabel;
    lbDonations: TListBox;
    lblExtra: TLabel;
    hlbExtra: THyperlinkButton;
    procedure FormShow(Sender: TObject);
  private
    fThanksTo: string;
    procedure GetRegistrationInformation(isNT: Boolean; var owner, organization: string);
  end;

  TNTAboutBox = class(TComponent)
  private
    fCopyright: string;
    fDisplayExtraLink: Boolean;
    fDisplaySupportLink: Boolean;
    fThanksTo: string;
    FExtraURL: string;
    FSupportURL: string;
  public
    procedure Execute;
  published
    property Copyright: string read fCopyright write fCopyright;
    property DisplayExtraLink: Boolean read fDisplayExtraLink write fDisplayExtraLink;
    property DisplaySupportLink: Boolean read fDisplaySupportLink write fDisplaySupportLink;
    property ThanksTo: string read fThanksTo write fThanksTo;
    property ExtraURL: string read FExtraURL write FExtraURL;
    property SupportURL: string read FSupportURL write FSupportURL;
  end;

function LoadGifResource(const resName: string; image: TImage): Boolean;

var
  fmNTAboutBox: TfmNTAboutBox;

implementation

{$R *.DFM}

uses
  Registry, gifimg, unitWow64, unitVersionHelpers;

function IsAMD64Arch : Boolean;
var lp : _SYSTEM_INFO;
begin
  GetNativeSystemInfo(lp);
  Result := lp.wProcessorArchitecture = PROCESSOR_ARCHITECTURE_AMD64;
end;

function LoadGifResource(const resName: string; image: TImage): Boolean;
var
  g: TGifImage;
  rs: TResourceStream;
begin
  Result := False;
  g := nil;
  if FindResource(hInstance, PChar(resName), 'GIF') <> 0 then
    try
      rs := TResourceStream.Create(hInstance, resName, 'GIF');
      try
        if rs.Size > 0 then
        begin
          g := TGifImage.Create;
          g.LoadFromStream(rs);
          image.Picture.Assign(g);
          Result := True;
        end;
      finally
        g.Free;
        rs.Free;
      end;
    except
    end;
end;

procedure TfmNTAboutBox.GetRegistrationInformation(isNT: Boolean; var owner, organization: string);
var
  os, product: string;
  p: Integer;
  reg: TRegistry;
  flags: LongWord;
  gotDetails: Boolean;
begin
  gotDetails := False;
  product := ExtractFileName(Application.ExeName);
  p := Pos('.', product);
  if p > 0 then
    Delete(product, p, Length(product));
  reg := TRegistry.Create(KEY_READ);
  try
    reg.RootKey := HKEY_LOCAL_MACHINE;
    if reg.OpenKey(Format('Software\Woozle\%s\CurrentVersion', [product]), False) then
      if reg.ValueExists('RegisteredOwner') and reg.ValueExists('RegisteredOrganization') then
      begin
        owner := reg.ReadString('RegisteredOwner');
        organization := reg.ReadString('RegisteredOrganization');
        gotDetails := True;
      end;
  finally
    reg.Free;
  end;

  if not gotDetails then
  begin
    owner := 'Owner';
    organization := 'Organization';

    flags := KEY_READ;
    if IsWow64 then
      flags := flags or KEY_WOW64_64KEY;
    reg := TRegistry.Create(flags);
    try
      reg.RootKey := HKEY_LOCAL_MACHINE;
      if isNT then
        os := 'Windows NT'
      else
        os := 'Windows';

      if reg.OpenKey(Format('Software\Microsoft\%s\CurrentVersion', [os]), False) then
      begin
        owner := reg.ReadString('RegisteredOwner');
        organization := reg.ReadString('RegisteredOrganization');
        gotDetails := True;
      end;
    finally
      reg.Free;
    end;

    if gotDetails then
      try
        reg := TRegistry.Create(KEY_READ or KEY_WRITE);
        try
          reg.RootKey := HKEY_LOCAL_MACHINE;
          if reg.OpenKey(Format('Software\Woozle\%s\CurrentVersion', [product]), True) then
          begin
            reg.WriteString('RegisteredOwner', owner);
            reg.WriteString('RegisteredOrganization', organization);
          end;
        finally
          reg.Free;
        end;
      except
      end;
  end;
end;

procedure TfmNTAboutBox.FormShow(Sender: TObject);
var
  memInfo: TMemoryStatusEx;
  os, owner, organization, st: string;
  Size, zero: DWORD;
  buffer, pBuffer: Pointer;
  info: PVSFixedFileInfo;
begin
  memInfo.dwLength := SizeOf(TMemoryStatusEx);
  GlobalMemoryStatusEx(memInfo);
  Caption := 'About ' + Application.Title;

  if not LoadGifResource(Application.Title, icoProduct) then
    if Assigned(Application.Icon) then
      icoProduct.Picture.Icon := Application.Icon;

  st := Application.Title;

  Size := GetFileVersionInfoSize(PChar(Application.ExeName), zero);
  if Size > 0 then
  begin
    GetMem(buffer, Size);
    try
      if not GetFileVersionInfo(PChar(Application.ExeName), zero, Size, buffer) then
        RaiseLastOSError;

      if not VerQueryValue(buffer, '\', pBuffer, Size) then
        RaiseLastOSError;

      info := PVSFixedFileInfo(pBuffer);

      TabSheet1.Caption := 'About ' + st;

      st := st + Format(' Version %d.%d.%d.%d',
         [HiWord(info^.dwProductVersionMS),
          LoWord(info^.dwProductVersionMS),
          HiWord(info^.dwProductVersionLS),
          LoWord(info^.dwProductVersionLS)]);
    finally
      FreeMem(buffer);
    end;
  end;

  if fThanksTo = '' then
  begin
    TabSheet2.Free;
  end
  else
  begin
    stThankYou.Caption :=
      'Many thanks for the generous donations from the following kind people!  ' +
      'Without these donations, ' + Application.Title + ' couldn''t have been written';
    lbDonations.Items.Text := fThanksTo;
  end;

  PageControl1.ActivePageIndex := 0;

  stProduct.Caption := st;

  os := '';
  if Win32Platform = VER_PLATFORM_WIN32_NT then
    case Win32MajorVersion of
      3, 4:
        os := 'Windows NT';
      5:
        if Win32MinorVersion = 0 then
          os := 'Windows 2000'
        else
          if Win32MinorVersion = 1 then
            os := 'Windows XP'
          else
            if IsAMD64Arch and (IsWindowsServer = False) then begin
              os := 'Windows XP Professional x64 Edition'
            end else begin
              if GetSystemMetrics(SM_SERVERR2) <> 0 then
                os := 'Windows Server 2003 R2'
              else
                os := 'Windows Server 2003';
            end;
      6:
        if Win32MinorVersion = 0 then begin
          if IsWindowsServer then begin
            os := 'Windows Server 2008'
          end else
            os := 'Windows Vista';
        end else
          if Win32MinorVersion = 1 then begin
            if IsWindowsServer then
               os := 'Windows Server 2008 R2'
            else
              os := 'Windows 7';
          end else begin
            if IsWindows8Point1OrGreater then begin
                if IsWindowsServer then begin
                  os := 'Windows Server 2012 R2';
                end else begin
                  os := 'Windows 8.1';
                end;
            end else begin
                if IsWindowsServer then begin
                  os := 'Windows Server 2012';
                 end else begin
                  os := 'Windows 8';
                end;
            end;
          end;
        end
  else
    case Win32MajorVersion of
      4:
        if Win32MinorVersion = 0 then
          os := 'Windows 95'
        else if Win32MinorVersion = 10 then
          os := 'Windows 98'
        else
          os := 'Windows ME';
    end;

  GetRegistrationInformation(Win32Platform = VER_PLATFORM_WIN32_NT, owner, organization);
  stLicense1.Caption := owner;
  stLicense2.Caption := organization;
  if Win32CSDVersion = '' then
    stVersion.Caption := Format('%s  (Build %d)', [os, Win32BuildNumber])
  else
    stVersion.Caption := Format('%s  (Build %d: %s)', [os, Win32BuildNumber, Win32CSDVersion]);
  stMemAvail.Caption := Format('Physical Memory Available to Windows: %10.0n KB',
    [memInfo.ullTotalPhys / 1024]);
  LoadGifResource(Application.Title + '1', icoProduct1);
end;

{ TNTAboutBox }

procedure TNTAboutBox.Execute;
var
  dlg: TfmNTAboutBox;
begin
  dlg := TfmNTAboutBox.Create(nil);
  try
    if Copyright <> '' then
      dlg.stCopyright.Caption := Copyright;

    if DisplaySupportLink then
    begin
      dlg.lblSupport.Visible := True;
      dlg.hlbSupport.Caption := SupportURL;
      dlg.hlbSupport.Link := SupportURL;
      dlg.hlbSupport.Visible := True;
    end;

    if DisplayExtraLink then
    begin
      dlg.lblExtra.Visible := True;
      dlg.hlbExtra.Caption := ExtraURL;
      dlg.hlbExtra.Link := ExtraURL;
      dlg.hlbExtra.Visible := True;
    end;

    dlg.fThanksTo := fThanksTo;

    dlg.ShowModal;
  finally
    dlg.Free;
  end;
end;

end.
