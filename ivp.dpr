program ivp;

uses
  Classes,
  Shellapi,
  Messages,
  GDIPAPI,
  GDIPOBJ,
  SysUtils,
  Windows,
  libwebp in 'lib\delphi-webp\src\libwebp.pas',
  WebpHelpers in 'lib\delphi-webp\src\WebpHelpers.pas',
  inet in 'inet.pas',
  ftype in 'ftype.pas';

type
  GET_X_LPARAM = Word;
  {$EXTERNALSYM GET_X_LPARAM}
  GET_Y_LPARAM = Word;
  {$EXTERNALSYM GET_Y_LPARAM} 

var
  Msg: TMSG;
  LWndClass: TWndClass;
  hMainHandle: HWND;
  bitmap: TGPBitmap;
  Scale : real = 1;
  Offset : TPoint;
  IsMouseClicking : boolean = false;
  xPos : Word = 0;
  yPos : Word = 0;
  current : Cardinal = 0;
  fullscreen : boolean = false;

  data : PByte;
  free_on_next_call : boolean = false;

  image_stack : TArray<string>;

const
  Stretch = true;
  Proportional = true;
  Center = true;
  Contain = true;
  Fit = true;
  defaultStyle = WS_VISIBLE or WS_CAPTION or WS_OVERLAPPED or WS_THICKFRAME or WS_MAXIMIZEBOX or WS_MINIMIZEBOX or WS_SYSMENU;

procedure ReleaseResources;
begin
  PostQuitMessage(0);
end;

procedure Draw;
var
  ps: tagPAINTSTRUCT;
  hdc, hdcMem, hbmp: Cardinal;
  G: TGPGraphics;
  destRect, srcRect : TGPRect;
  winRect : TRect;
begin
  if Length(image_stack) = 0 then exit;

  GetClientRect(hMainHandle, winRect);

  hdc := BeginPaint(hMainHandle, ps);

  hdcMem := CreateCompatibleDC(hdc);
  hbmp := CreateCompatibleBitmap(hdc, winRect.Width, winrect.Height);
  SelectObject(hdcMem, hBmp);

  destRect.X := 0;
  destRect.Y := 0;
  destRect.Width := Bitmap.GetWidth;
  destRect.Height := Bitmap.GetHeight;

  srcRect.X := 0;
  srcRect.Y := 0;
  srcRect.Width := Bitmap.GetWidth;
  srcRect.Height := Bitmap.GetHeight;

  if Stretch then
  begin
    destRect.Width := winRect.Width;
    destRect.Height := winRect.Height;
  end;

  if Stretch and Proportional then
  begin
    if (winRect.Height > 0) and (srcRect.Height > 0) and (srcRect.Width > 0) then
      if (srcRect.Width / srcRect.Height) - (winRect.Width / winRect.Height) < 0 then
        destRect.Width := Trunc(srcRect.Width * (destRect.Height / srcRect.Height))
      else
        destRect.Height := Trunc(srcRect.Height * (destRect.Width / srcRect.Width))
  end;

  if Stretch and Fit and Proportional then
  begin
    if destRect.Width > srcRect.Width then
    begin
      destRect.Width := srcRect.Width;
      destRect.Height := srcRect.Height;
    end;
  end;

  destRect.Height := Trunc(destRect.Height * Scale);
  destRect.Width := Trunc(destRect.Width * Scale);

  if Center then
  begin
    destRect.X := Trunc((winRect.Width / 2) - (destRect.Width / 2));
    destRect.Y := Trunc((winRect.Height / 2) - (destRect.Height / 2));
  end;

  destRect.X := destRect.X - Offset.X;
  destRect.Y := destRect.Y - Offset.Y;

  // Draw to canvas
  G := TGPGraphics.Create(hdcMem);
  try
    if IsMouseClicking then
    begin
      // Faster Panning
      G.SetCompositingMode(CompositingModeSourceOver);
      G.SetInterpolationMode(InterpolationModeNearestNeighbor);
      G.SetPixelOffsetMode(PixelOffsetModeHighSpeed);
      G.SetSmoothingMode(SmoothingModeHighSpeed);
    end
    else
    begin
      G.SetCompositingMode(CompositingModeSourceOver);
      G.SetInterpolationMode(InterpolationModeHighQualityBicubic);
      G.SetPixelOffsetMode(PixelOffsetModeHighQuality);
      G.SetSmoothingMode(SmoothingModeAntiAlias);
    end;
    G.DrawImage(bitmap, destRect, srcRect.x, srcRect.Y, srcRect.Width, srcRect.Height, UnitPixel);
  finally
    G.Free;
  end;

  BitBlt(hdc, 0, 0, winRect.Width, winRect.Height, hdcMem, 0, 0, SRCCOPY);

  DeleteObject(hbmp);
  DeleteDC(hdcMem);

  EndPaint(hMainHandle, ps);
end;

procedure ResetPosition;
begin
  Offset.X := 0;
  Offset.Y := 0;
  Scale := 1;
end;

procedure ToggleFullscreen;
type
  HMONITOR = type THandle;
  TMonitorInfo = record
    cbSize: DWORD;
    rcMonitor: TRect;
    rcWork: TRect;
    dwFlags: DWORD;
  end;
const
  MONITOR_DEFAULTTONEAREST = $00000002;
var
  Module: HMODULE;
  MonitorFromWindow: function(HWND: HWND; dwFlags: DWORD): HMONITOR; stdcall;
  GetMonitorInfo: function(hMonitor: HMONITOR; var lpmi: TMonitorInfo): BOOL; stdcall;
  Info: TMonitorInfo;
begin
  fullscreen := not fullscreen;

  if fullscreen then
  begin
    SetWindowLongPtr(hMainHandle, GWL_STYLE, WS_VISIBLE);
    SetWindowLongPtr(hMainHandle, GWL_EXSTYLE, 0);
    // delphi doesn't include the declarations for GetMonitorInfo so let's get it

    // source from: https://stackoverflow.com/questions/7077572/get-current-native-screen-resolution-of-all-monitors-in-delphi-directx
    Module := GetModuleHandle(user32);
    MonitorFromWindow := GetProcAddress(Module, 'MonitorFromWindow');
    GetMonitorInfo := GetProcAddress(Module, 'GetMonitorInfoA');
    if Assigned(MonitorFromWindow) and Assigned(GetMonitorInfo) then
    begin
      Info.cbSize := SizeOf(Info);
      GetMonitorInfo(MonitorFromWindow(hMainHandle, MONITOR_DEFAULTTONEAREST), Info);
      SetWindowPos(hMainHandle, 0, Info.rcMonitor.top, Info.rcMonitor.left, Info.rcMonitor.width, Info.rcMonitor.height, SWP_NOZORDER or SWP_NOACTIVATE or SWP_FRAMECHANGED)
    end;
  end
  else
  begin
    SetWindowLongPtr(hMainHandle, GWL_STYLE, defaultStyle);
    SetWindowPos(hMainHandle, 0, (GetSystemMetrics(SM_CXSCREEN) div 2) - 640,
    (GetSystemMetrics(SM_CYSCREEN) div 2) - 360,
    1280,
    720, SWP_NOZORDER or SWP_NOACTIVATE or SWP_FRAMECHANGED)
  end;
  
  DragAcceptFiles(hMainHandle, true);
end;

procedure LoadImage(uri: string);
var
  ms: TMemoryStream;
  IsLocalFile: boolean;
  magic : TArray<byte>;
begin
  SetWindowText(hMainHandle, Format('[ %d / %d ] %s', [current + 1, length(image_stack), uri]));

  IsLocalFile := not ((Pos('http://', uri) = 1) or (Pos('https://', uri) = 1));

  if bitmap <> nil then FreeAndNil(bitmap);

  if free_on_next_call then WebPFree(data);
  free_on_next_call := false;

  if IsLocalFile then
  begin
    ms := TMemoryStream.Create;
    Setlength(magic, 20);
    try
      ms.LoadFromFile(uri);
      if ms.Size < 20 then
      begin
        bitmap := TGPBitmap.Create;
        raise Exception.Create('File size too small.');
      end;
      ms.Position := 0;
      ms.ReadBuffer(magic, 20);
      if IsGDISupported(@magic[0], 20) then
      begin
        bitmap := TGPBitmap.Create(uri)
      end
      else if IsWebp(@magic[0], 20) then
      begin
        WebpDecode(ms, data, bitmap);
        free_on_next_call := true;
      end
      else
        bitmap := TGPBitmap.Create;
    finally
      ms.Free;
    end;
  end
  else bitmap := GETImageFromURL(uri, data, free_on_next_call);

  InvalidateRect(hMainHandle, nil, false);
end;

procedure PushImageToStack(uri: string);
begin
  SetLength(image_stack, length(image_stack) + 1);
  image_stack[high(image_stack)] := uri;
  if bitmap = nil then LoadImage(image_stack[0]);
  SetWindowText(hMainHandle, Format('[ %d / %d ] %s', [current + 1, length(image_stack), uri]));
end;

procedure PushURIToStack(uri: string);
var
  FindFileData: TWIN32FindData;
  hFind, uri_type: Cardinal;
begin
  if ((Pos('http://', uri) = 1) or (Pos('https://', uri) = 1)) then
  begin
    PushImageToStack(uri);
    exit;
  end;
  
  uri_type := GetFileAttributes(PWideChar(uri));

  if (uri_type and FILE_ATTRIBUTE_DIRECTORY) <> FILE_ATTRIBUTE_DIRECTORY then
  begin
    PushImageToStack(uri);
    exit;
  end;

  // If directory clear stack
  SetLength(image_stack, 0);
  current := 0;

  SetCurrentDirectory(PWideChar(uri));

  hFind := FindFirstFile('.\*', FindFileData);

  if hFind <> INVALID_HANDLE_VALUE then
  begin
    repeat
      if (FindFileData.dwFileAttributes and FILE_ATTRIBUTE_DIRECTORY) <> FILE_ATTRIBUTE_DIRECTORY then
      begin
        PushImageToStack(FindFileData.cFileName);
      end;
    until (not FindNextFile(hFind, FindFileData));
  end;

  FindClose(hFind);
end;

procedure Initialize;
var
  c: integer;
begin
  SetLength(image_stack, 0);
  for c := 1 to ParamCount do
  begin
    PushURIToStack(ParamStr(c));
  end;
end;

procedure HandleMouseMove(wParam: wParam; lParam: lParam);
var
  nX, nY : Word;
begin
  nX := LOWORD(lParam);
  nY := HIWORD(lParam);
  if IsMouseClicking then
  begin
    Offset.X := Offset.X - (nX - xPos);
    Offset.Y := Offset.Y - (nY - yPos);
    InvalidateRect(hMainHandle, nil, false);
  end;
  IsMouseClicking := Boolean(wParam and MK_LBUTTON);
  xPos := nX;
  yPos := nY;
end;

procedure HandleFileDrop(wParam: wParam);
var
  c, i: integer;
  file_path : array[0..MAX_PATH - 1] of Char;
begin
  c := DragQueryFile(wParam, $FFFFFFFF, file_path, SizeOf(file_path));

  for i := 0 to c - 1 do
  begin
    DragQueryFile(wParam, i, file_path, SizeOf(file_path));
    PushURIToStack(file_path);
  end;
  
  DragFinish(wParam);
end;

procedure Navigate(next: boolean);
begin
  if next then
  begin
    inc(current);
    if current >= length(image_stack) then current := Length(image_stack) - 1;
    LoadImage(image_stack[current]);
  end
  else
  begin
    if current > 0 then
    begin
      dec(current);
      LoadImage(image_stack[current]);
    end;
  end;
  ResetPosition;
  Draw; // force draw
end;

function WindowProc(HWND, Msg: Longint; wParam: wParam; lParam: lParam)
  : Longint; stdcall;
begin
  case Msg of
    WM_KEYDOWN:
      begin
        case wParam of
          VK_LEFT: Navigate(false);
          VK_RIGHT: Navigate(true);
          VK_UP:
            begin
              Scale := Scale / 0.5;
              InvalidateRect(hMainHandle, nil, false)
            end;
          VK_DOWN:
            begin
              Scale := Scale * 0.5;
              InvalidateRect(hMainHandle, nil, false)
            end;
          $46: ToggleFullscreen;
          $51: ReleaseResources;
        end;
      end;
    WM_MOUSEMOVE: HandleMouseMove(wParam, lParam);
    WM_LBUTTONUP:
      begin
        IsMouseClicking := false;
        InvalidateRect(hMainHandle, nil, false);
      end;
    WM_DESTROY: ReleaseResources;
    WM_PAINT: Draw;
    WM_SIZE: InvalidateRect(hMainHandle, Nil, false);
    WM_SIZING: InvalidateRect(hMainHandle, nil, false);
    WM_DROPFILES: HandleFileDrop(wParam);
  end;
  Result := DefWindowProc(HWND, Msg, wParam, lParam);
end;

begin
  LWndClass.hInstance := hInstance;

  with LWndClass do
  begin
    lpszClassName := 'MainWnd';
    Style := CS_PARENTDC or CS_BYTEALIGNCLIENT;
    hIcon := LoadIcon(hInstance, 'MAINICON');
    lpfnWndProc := @WindowProc;
    hbrBackground := CreateSolidBrush(RGB(0,0,0));
    hCursor := LoadCursor(0, IDC_ARROW);
  end;
  RegisterClass(LWndClass);

  hMainHandle := CreateWindowEx(
    WS_EX_DLGMODALFRAME,
    LWndClass.lpszClassName,
    'Image Viewer Plus',
    defaultStyle,
    (GetSystemMetrics(SM_CXSCREEN) div 2) - 640,
    (GetSystemMetrics(SM_CYSCREEN) div 2) - 360,
    1280,
    720,
    0,
    0,
    hInstance,
    nil);

  DragAcceptFiles(hMainHandle, true);

  bitmap := nil;

  Initialize;

  ResetPosition;

  // message loop
  while GetMessage(Msg, 0, 0, 0) do
  begin
    TranslateMessage(Msg);
    DispatchMessage(Msg);
  end;

end.
