unit inet;

interface

uses
  Windows, Wininet, System.Classes, GDIPAPI, GDIPOBJ, SysUtils, libwebp,
  WebpHelpers, ftype;

function GETImageFromURL (URL: string; var data : PByte; var free_on_next_call: boolean) : TGPBitmap;

implementation

function GETImageFromURL (URL: string; var data : PByte; var free_on_next_call: boolean) : TGPBitmap;
var
  hInet, hCon, hReq : HINTERNET;
  avail, BytesRead, openflags: Cardinal;
  buffer : TBytes;
  ms : TMemoryStream;
  magic : TBytes;
  error : string;
  lpszScheme      : array[0..INTERNET_MAX_SCHEME_LENGTH - 1] of Char;
  lpszHostName    : array[0..INTERNET_MAX_HOST_NAME_LENGTH - 1] of Char;
  lpszUserName    : array[0..INTERNET_MAX_USER_NAME_LENGTH - 1] of Char;
  lpszPassword    : array[0..INTERNET_MAX_PASSWORD_LENGTH - 1] of Char;
  lpszUrlPath     : array[0..INTERNET_MAX_PATH_LENGTH - 1] of Char;
  lpszExtraInfo   : array[0..1024 - 1] of Char;
  lpUrlComponents : TURLComponents;
begin
  result := nil;
  error := '';

  if free_on_next_call then WebPFree(data);

  free_on_next_call := false;

  setlength(magic, 20);

  try
    try
      ZeroMemory(@lpszScheme, SizeOf(lpszScheme));
      ZeroMemory(@lpszHostName, SizeOf(lpszHostName));
      ZeroMemory(@lpszUserName, SizeOf(lpszUserName));
      ZeroMemory(@lpszPassword, SizeOf(lpszPassword));
      ZeroMemory(@lpszUrlPath, SizeOf(lpszUrlPath));
      ZeroMemory(@lpszExtraInfo, SizeOf(lpszExtraInfo));
      ZeroMemory(@lpUrlComponents, SizeOf(TURLComponents));

      lpUrlComponents.dwStructSize      := SizeOf(TURLComponents);
      lpUrlComponents.lpszScheme        := lpszScheme;
      lpUrlComponents.dwSchemeLength    := SizeOf(lpszScheme);
      lpUrlComponents.lpszHostName      := lpszHostName;
      lpUrlComponents.dwHostNameLength  := SizeOf(lpszHostName);
      lpUrlComponents.lpszUserName      := lpszUserName;
      lpUrlComponents.dwUserNameLength  := SizeOf(lpszUserName);
      lpUrlComponents.lpszPassword      := lpszPassword;
      lpUrlComponents.dwPasswordLength  := SizeOf(lpszPassword);
      lpUrlComponents.lpszUrlPath       := lpszUrlPath;
      lpUrlComponents.dwUrlPathLength   := SizeOf(lpszUrlPath);
      lpUrlComponents.lpszExtraInfo     := lpszExtraInfo;
      lpUrlComponents.dwExtraInfoLength := SizeOf(lpszExtraInfo);

      if not InternetCrackUrl(PWideChar(URL), Length(URL), ICU_DECODE or ICU_ESCAPE, lpUrlComponents) then
        raise Exception.Create('Failed to crack URL.');

      hInet := InternetOpen(
        'Image Viewer Plus (github.com/Wykerd/image-viewer-plus)',
        INTERNET_OPEN_TYPE_DIRECT,
        nil, nil, 0
      );

      if not Assigned(hInet) then
        raise Exception.Create('Failed to initialize internet access.');

      hCon := InternetConnect(
        hInet,
        lpszHostName,
        INTERNET_DEFAULT_HTTPS_PORT,
        lpszUserName,
        lpszPassword,
        INTERNET_SERVICE_HTTP,
        0,
        0
      );

      if not Assigned(hCon) then
        raise Exception.Create('Failed to connect to host.');

      if lpszScheme = 'http' then openflags := INTERNET_FLAG_RAW_DATA
      else if lpszScheme = 'https' then openflags := INTERNET_FLAG_SECURE
      else raise Exception.Create('Only HTTP and HTTPS protocols supported');

      hReq := HttpOpenRequest(
        hCon,
        'GET',
        lpszUrlPath,
        nil,
        nil,
        nil,
        openflags,
        0
      );

      if not Assigned(hReq) then
        raise Exception.Create('Failed to open request to resource.');

      if HttpSendRequest(hReq, nil, 0, @lpszExtraInfo[0], lpUrlComponents.dwExtraInfoLength) then
      begin
        // Now download the buffer
        if InternetQueryDataAvailable(hReq, avail, 0, 0) then
        begin
          Setlength(buffer, avail + 1);
          ms := TMemoryStream.Create;
          try
            while InternetReadFile(hReq, @buffer[0], avail + 1, BytesRead) do
            begin
              if (BytesRead = 0) then Break;
              ms.Write(buffer, BytesRead);
            end;
            if ms.Size < 20 then raise Exception.Create('File too small.');
            ms.Position := 0;
            ms.ReadBuffer(magic, 20);
            if IsGDISupported(@magic[0], 20) then
              result := TGPBitmap.Create(TStreamAdapter.Create(ms))
            else if IsWebp(@magic[0], 20) then
            begin
              WebpDecode(ms, data, result);
              free_on_next_call := true;
            end
            else raise Exception.Create('Unsupported file type.');
          finally
            ms.Free;
          end;
        end;
      end;
    except on E: Exception do
      error := E.Message;
    end;
  finally
    SetLength(magic, 0);
    SetLength(buffer, 0);

    InternetCloseHandle(hReq);
    InternetCloseHandle(hCon);
    InternetCloseHandle(hInet);
  end;

  if result = nil then
  begin
    if error = '' then error := 'Failed to load image.';
    raise Exception.Create(error);
  end;
end;

end.
