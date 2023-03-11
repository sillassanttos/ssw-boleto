unit boleto.util.converte.arquivo.base64;

{$MODE DELPHI}{$H+}

interface

uses
  IdCoderMIME,
  Classes,
  SysUtils;

type
  TConverteArquivoBase64 = class
  public
    class function Converter(const AArquivo: string): string;
  end;

implementation

class function TConverteArquivoBase64.Converter(const AArquivo: string): string;
var
  LStream: TFileStream;
  LBase64: TIdEncoderMIME;
  LOutPut: string;
begin
  LOutPut := EmptyStr;
  LBase64 := TIdEncoderMIME.Create(nil);
  LStream := TFileStream.Create(AArquivo, fmOpenRead);
  try
    LOutPut := TIdEncoderMIME.EncodeStream(LStream);
  finally
    LStream.Free;
    LBase64.Free;
    Result := LOutPut;
  end;
end;

end.

