{
Determine the file type by reading the file signature (or magic number) from
the file buffer.
}

unit ftype;

interface

function IsGIF (buffer: PByte; count: Cardinal) : boolean;
function IsPNG (buffer: PByte; count: Cardinal) : boolean;
function IsJPG (buffer: PByte; count: Cardinal) : boolean;
function IsTIFF(buffer: PByte; count: Cardinal) : boolean;
function IsBMP (buffer: PByte; count: Cardinal) : boolean;
function IsWEBP(buffer: PByte; count: Cardinal) : boolean;
function IsGDISupported(buffer: PByte; count: Cardinal) : boolean;

implementation

function IsGIF(buffer: PByte; count: Cardinal) : boolean;
begin
  if count < 3 then exit(false);
  exit((buffer[0] = $47) and (buffer[1] = $49) and (buffer[2] = $46));
end;

function IsPNG(buffer: PByte; count: Cardinal) : boolean;
begin
  if count < 8 then exit(false);
  exit((buffer[0] = $89) and (buffer[1] = $50) and (buffer[2] = $4E) and
    (buffer[3] = $47) and (buffer[4] = $0D) and (buffer[5] = $0A) and
    (buffer[6] = $1A) and (buffer[7] = $0A));
end;

function IsJPG(buffer: PByte; count: Cardinal) : boolean;
begin
  if count < 2 then exit(false);
  exit((buffer[0] = $FF) and (buffer[1] = $D8))
end;

function IsTIFF(buffer: PByte; count: Cardinal) : boolean;
begin
  if count < 4 then exit(false);
  exit(((buffer[0] = $49) and (buffer[1] = $49) and (buffer[2] = $2A) and (buffer[3] = $00))
  or ((buffer[0] = $4D) and (buffer[1] = $4D) and (buffer[2] = $00) and (buffer[3] = $2A)));
end;

function IsBMP(buffer: PByte; count: Cardinal) : boolean;
begin
  if count < 2 then exit(false);
  exit((buffer[0] = $42) and (buffer[1] = $4D));
end;

function IsWEBP(buffer: PByte; count: Cardinal) : boolean;
begin
  if count < 12 then exit(false);
  exit((buffer[0] = $52) and (buffer[1] = $49) and (buffer[2] = $46) and (buffer[3] = $46) and
       (buffer[8] = $57) and (buffer[9] = $45) and (buffer[10] = $42) and (buffer[11] = $50));
end;

function IsGDISupported(buffer: PByte; count: Cardinal) : boolean;
begin
  result := false;
  if IsGIF(buffer, count) then exit(true);
  if IsPNG(buffer, count) then exit(true);
  if IsJPG(buffer, count) then exit(true);
  if IsTIFF(buffer, count) then exit(true);
  if IsBMP(buffer, count) then exit(true);
end;

end.
