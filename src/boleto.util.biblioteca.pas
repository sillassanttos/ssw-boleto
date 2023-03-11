unit boleto.util.biblioteca;

{$MODE DELPHI}{$H+}

interface

uses
  Classes,
  SysUtils;

function Qt(AValue: string = ''): string;
function IfThen(ACondicao: Boolean; AVerdadeiro, AFalso: string): string;

const
  captionApp = 'Boletos Bancários - Remessa e Retorno';

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

end.

