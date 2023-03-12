unit boleto.controller;

{$MODE DELPHI}{$H+}

interface

uses
  Horse,
  //Horse.OctetStream,
  Classes,
  SysUtils,
  boleto.database,
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

procedure DoGerarBoleto(Req: THorseRequest; Res: THorseResponse);
begin
  with TDM.Create(nil) do
  try
    Res.Send(GerarBoleto(Req.Params['id_empresa'], Req.Params['id_receber'], Req.Params['parcela']));
  finally
    Free;
  end;
end;

{ TBoletoController }
class procedure TBoletoController.Registry;
begin
  THorse
    .Get(GPrefixo + 'status', DoStatus)
    .Get(GPrefixo + 'gerar/:id_empresa/:id_receber/:parcela', DoGerarBoleto)
    //.Get(PREFIXO + 'remessa/:id_empresa/:id_remessa', DoGerarRemessa)
    //.Put(PREFIXO + 'enviar-email', DoEnviarEmail)
end;


end.

