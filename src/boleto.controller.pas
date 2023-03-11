unit boleto.controller;

{$MODE DELPHI}{$H+}

interface

uses
  Horse,
  //Horse.OctetStream,
  Classes,
  SysUtils,
  boleto.util.biblioteca,
  boleto.util.terceiro.j4dl;

type
  TBoletoController = class
  public
    class procedure Registry;
  end;

implementation

procedure DoStatus(Req: THorseRequest; Res: THorseResponse);
begin
  with TJson.Create do
  begin
    Put('sucesso' , True);
    Put('mensagem', Concat('Serviço em operação, em: ', DateTimeToStr(Now)));
    Res.Send(Stringify);
  end;
end;

{ TBoletoController }
class procedure TBoletoController.Registry;
begin
  THorse
    .Get(GPrefixo + 'status', DoStatus);
    //.Get(PREFIXO + 'gerar/:id_empresa/:id_receber/:parcela', DoGerarBoleto)
    //.Get(PREFIXO + 'remessa/:id_empresa/:id_remessa', DoGerarRemessa)
    //.Put(PREFIXO + 'enviar-email', DoEnviarEmail)
end;


end.

