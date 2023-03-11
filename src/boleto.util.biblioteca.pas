unit boleto.util.biblioteca;

{$MODE DELPHI}{$H+}

interface

uses
  Classes,
  SysUtils;

function Qt(AValue: string = ''): string;
function IfThen(ACondicao: Boolean; AVerdadeiro, AFalso: string): string;
function RemoveChar(const Texto: string; strChar: string = ''): string;

var
  GCaptionApp: string;
  GTituloApp: string;
  GPrefixo: string;

const

  sl  = sLineBreak;
  sl2 = sl + sl;

implementation

function Qt(AValue: string = ''): string;
begin
  Result := QuotedStr(AValue);
end;

function IfThen(ACondicao: Boolean; AVerdadeiro, AFalso: string): string;
begin
  Result := AVerdadeiro;

  if not ACondicao then
    Result := AFalso;
end;

function RemoveChar(const Texto: string; strChar: string): string;
var
  I: Integer;
begin
  Result := '';

  if (strChar = '') then
  begin
    for I := 1 to Length(Texto) do
      if (Texto[I] in ['0'..'9']) then
        Result := Result + Copy(Texto, I, 1);
  end
  else
  for I := 1 to Length(Texto) do
    if (Texto[I] <> strChar) then
      Result := Result + Copy(Texto, I, 1);
end;

end.

