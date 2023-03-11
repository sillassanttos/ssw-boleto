unit boleto.database;

{$MODE DELPHI}{$H+}

interface

uses
  Classes,
  SysUtils,

  ACBrUtil,
  ACBrBoletoFCFortesFr,
  ACBrBase,
  ACBrBoletoConversao,
  ACBrExtenso,
  ACBrBoleto,
  ACBrMail,

  DB,
  IniFiles,
  ZConnection,
  ZDataset,
  Forms,

  boleto.util.biblioteca,
  boleto.util.terceiro.j4dl,
  boleto.util.converte.arquivo.base64;

type

  { TDM }

  TDM = class(TDataModule)
    ACBrBoleto1: TACBrBoleto;
    ACBrBoletoFCFortes1: TACBrBoletoFCFortes;
    ACBrExtenso: TACBrExtenso;
    ACBrMail1: TACBrMail;
    Conexao: TZConnection;
    procedure ConexaoBeforeConnect(Sender: TObject);
    procedure DataModuleCreate(Sender: TObject);
    procedure DataModuleDestroy(Sender: TObject);
    procedure QryEmpresaAfterOpen(DataSet: TDataSet);
    procedure QryReceberAfterOpen(DataSet: TDataSet);
    procedure QryConfiguracaoAfterOpen(DataSet: TDataSet);
  private
    FRetorno: TJson;

    FQryEmpresa: TZQuery;
    FQryReceber: TZQuery;
    FQryPessoa: TZQuery;
    FQryConfiguracao: TZQuery;
    FQryRemessa: TZQuery;
    FQryReceberDetalhe: TZQuery;

    function CriarQuery: TZQuery;
    procedure AbrirEmpresa(const AIDEmpresa: string);
    procedure AbrirReceber(const AIDEmpresa, AIDReceber, AParcela: string);
    procedure ConfigurarBoleta;
    procedure PrepararBoleto(const AIDEmpresa, AIDReceber, AParcela, GerarRemessa: string; var ADiretorio: string; var AArquivo: string);
    procedure ProcessaRetorno(const AMensagem: string; const ASucesso: Boolean = True; const ABase64: string = '');
  public
    function GerarBoleto(const AIDEmpresa, AIDReceber, AParcela: string): string;
  end;

var
  DM: TDM;

implementation

{$R *.lfm}

procedure TDM.ConexaoBeforeConnect(Sender: TObject);
begin
  with TIniFile.Create(ChangeFileExt('boleto', '.ini')) do
  try
    Conexao.HostName := ReadString('Database', 'IP', '');
    Conexao.Database := ReadString('Database', 'BancoDados', '');
    Conexao.Protocol := ReadString('Database', 'Protocolo', '');
    Conexao.User := ReadString('Database', 'Usuario', '');
    Conexao.Password := ReadString('Database', 'Senha', '');
    Conexao.Port := ReadInt64('Database', 'PortaDB', 3306);
    Conexao.LibraryLocation := ReadString('Database', 'LibraryLocation', '');
  finally
    Free;
  end;
end;

procedure TDM.DataModuleCreate(Sender: TObject);
begin
  FQryEmpresa := CriarQuery;
  FQryEmpresa.AfterOpen := QryEmpresaAfterOpen;

  FQryPessoa := CriarQuery;

  FQryReceber := CriarQuery;
  FQryReceber.AfterOpen := QryReceberAfterOpen;

  FQryConfiguracao := CriarQuery;
  FQryConfiguracao.AfterOpen := QryConfiguracaoAfterOpen;

  FQryRemessa := CriarQuery;

  FQryReceberDetalhe := CriarQuery;
end;

procedure TDM.DataModuleDestroy(Sender: TObject);
begin
  FreeAndNil(FQryEmpresa);
  FreeAndNil(FQryPessoa);
  FreeAndNil(FQryReceber);
  FreeAndNil(FQryConfiguracao);
  FreeAndNil(FQryRemessa);
  FreeAndNil(FQryReceberDetalhe);
end;

procedure TDM.QryEmpresaAfterOpen(DataSet: TDataSet);
begin
  if DataSet.IsEmpty then
    raise Exception.Create('Empresa não encontrada!');

  FQryConfiguracao.Close;
  FQryConfiguracao.SQL.Text :=
    Concat(
      sl, ' select boleto_instrucao1 as instrucao1 ',
      sl, '      , boleto_instrucao2 as instrucao2 ',
      sl, '      , boleto_instrucao3 as instrucao3 ',
      sl, '      , boleto_instrucao_ao_sacado as instrucao_ao_sacado ',
      sl, '      , boleto_local_pagamento as local_pagamento ',
      sl, '      , boleto_valor_acrescimo as valor_acrescimo ',
      sl, '      , boleto_valor_deducao as valor_deducao ',
      sl, '      , boleto_valor_desconto as valor_desconto ',
      sl, '      , boleto_valor_mora as valor_mora ',
      sl, '      , boleto_codigo_cedente as codigo_cedente ',
      sl, '      , boleto_convenio as convenio ',
      sl, '      , boleto_modalidade as modalidade ',
      sl, '      , boleto_layout_impressao as layout_impressao ',
      sl, '      , financeiro_id_conta_boleto as id_conta_boleto ',
      sl, '      , financeiro_id_agencia as id_agencia ',
      sl, '      , financeiro_id_banco as id_banco ',
      sl, '      , financeiro_dias_carencia as dias_carencia ',
      sl, '      , financeiro_taxa_juro as taxa_juro ',
      sl, '      , financeiro_taxa_desconto as taxa_desconto ',
      sl, '      , financeiro_tipo_juro as tipo_juro ',
      sl, '      , cc.nome as conta_nome ',
      sl, '      , cc.tipo as conta_tipo ',
      sl, '      , cc.numero as conta_numero ',
      sl, '      , cc.digito as conta_digito ',
      sl, '      , cc.carteira as conta_carteira ',
      sl, '      , a.numero as agencia_numero ',
      sl, '      , a.digito as agencia_digito ',
      sl, '      , b.nome as banco_nome ',
      sl, '      , b.tipo_cobranca ',
      sl, '      , email_autenticar as email_autenticar ',
      sl, '      , email_autenticar_tls as email_tls ',
      sl, '      , email_autenticar_ssl as email_ssl ',
      sl, '      , email_porta as email_porta ',
      sl, '      , email_remetente as email_remetente ',
      sl, '      , email_endereco_host as email_host ',
      sl, '      , email_senha as email_senha ',
      sl, '      , email_assunto as email_assunto ',
      sl, '      , email_mensagem as email_mensagem ',
      sl, '   from configuracao c, ',
      sl, '        conta_caixa cc, ',
      sl, '        agencia a, ',
      sl, '        banco b ',
      sl, '  where c.id_empresa = ', DataSet.FieldByName('id').AsString,
      sl, '    and cc.id  = financeiro_id_conta_boleto ',
      sl, '    and a.id = cc.id_agencia ',
      sl, '    and b.id = a.id_banco '
    );
  FQryConfiguracao.Open;

  if FQryConfiguracao.IsEmpty then
    raise Exception.Create('Configuração não encontrada!');
end;

procedure TDM.QryReceberAfterOpen(DataSet: TDataSet);
begin
  if DataSet.IsEmpty then
    raise Exception.Create('Dados titulo não encontrado!');

  FQryPessoa.Close;
  FQryPessoa.SQL.Text :=
    Concat(
      sl, ' select p.id as id_pessoa ',
      sl, '      , p.nome ',
      sl, '      , p.nome_fantasia ',
      sl, '      , p.email ',
      sl, '      , p.cpf_cnpj ',
      sl, '      , p.rg_inscricao_estadual as inscricao_estadual ',
      sl, '      , p.tipo ',
      sl, '      , p.tipo_contribuinte ',
      sl, '      , pe.logradouro as endereco ',
      sl, '      , pe.numero ',
      sl, '      , pe.complemento ',
      sl, '      , pe.bairro ',
      sl, '      , pe.cidade ',
      sl, '      , pe.ibge_cidade ',
      sl, '      , pe.uf ',
      sl, '      , pe.ibge_uf ',
      sl, '      , pe.cep ',
      sl, '      ,(case ',
      sl, '       when ((coalesce(trim(pe.telefone), '''') = '''') ',
      sl, '         or (length(coalesce(trim(pe.telefone), '''')) = 0)) ',
      sl, '       then (select pt.numero ',
      sl, '               from pessoa_telefone pt ',
      sl, '              where pt.id_pessoa = pe.id_pessoa ',
      sl, '                and pt.tipo = ''P'' ',
      sl, '              order by pt.id ',
      sl, '              limit 1) ',
      sl, '       else pe.telefone ',
      sl, '        end) as telefone ',
      sl, '     , ''S'' as tipo_frete ',
      sl, '  from pessoa p ',
      sl, '  left ',
      sl, '  join pessoa_empresa em ',
      sl, '    on em.id_pessoa = p.id ',
      sl, '  left ',
      sl, '  join pessoa_endereco pe ',
      sl, '    on pe.id_pessoa = p.id ',
      sl, '   and pe.tipo = ''P'' /* Principal */ ',
      sl, ' where coalesce(p.excluido, ''N'') = ''N'' ',
      sl, '   and p.id = ', DataSet.FieldByName('id_pessoa').AsString,
      sl, '   and em.id_empresa = ', DataSet.FieldByName('id_empresa').AsString
    );
  FQryPessoa.Open;

  if FQryPessoa.IsEmpty then
    raise Exception.Create('Pessoa não encontrada!');
end;

procedure TDM.QryConfiguracaoAfterOpen(DataSet: TDataSet);
begin
  ACBrMail1.IsHTML   := False;
  ACBrMail1.Host     := FQryConfiguracao.FieldByName('email_host').AsString.Trim;
  ACBrMail1.Port     := FQryConfiguracao.FieldByName('email_porta').AsString.Trim;
  ACBrMail1.Username := FQryConfiguracao.FieldByName('email_remetente').AsString.Trim;
  ACBrMail1.Password := FQryConfiguracao.FieldByName('email_senha').AsString.Trim;
  ACBrMail1.SetSSL   := FQryConfiguracao.FieldByName('email_ssl').AsString.Trim.Equals('S');
  ACBrMail1.SetTLS   := FQryConfiguracao.FieldByName('email_tls').AsString.Trim.Equals('S');
end;

function TDM.CriarQuery: TZQuery;
begin
  Result := TZQuery.Create(nil);
  Result.Connection := Conexao;
  Result.SQL.Clear;
end;

procedure TDM.AbrirEmpresa(const AIDEmpresa: string);
begin
  FQryEmpresa.Close;
  FQryEmpresa.SQL.Text :=
    Concat(
      sl, ' select e.id ',
      sl, '      , e.razao_social ',
      sl, '      , e.nome_fantasia ',
      sl, '      , e.cnpj ',
      sl, '      , e.inscricao_estadual ',
      sl, '      , e.inscricao_estadual_st ',
      sl, '      , e.inscricao_municipal ',
      sl, '      , e.crt ',
      sl, '      , e.email ',
      sl, '      , e.situacao ',
      sl, '      , coalesce(e.percentual_credito_sn, 0) as percentual_credito_sn ',
      sl, '      , ee.logradouro as endereco ',
      sl, '      , ee.numero ',
      sl, '      , ee.complemento ',
      sl, '      , ee.bairro ',
      sl, '      , ee.cidade ',
      sl, '      , ee.ibge_cidade ',
      sl, '      , ee.uf ',
      sl, '      , ee.ibge_uf ',
      sl, '      , ee.cep ',
      sl, '      , ee.telefone ',
      sl, '   from empresa e ',
      sl, '   left ',
      sl, '   join empresa_endereco ee ',
      sl, '     on ee.id_empresa = e.id ',
      sl, '    and ee.tipo = ', Qt('P'), ' /* P-Principal */ ',
      sl, '  where e.id = :id_empresa '
    );
  FQryEmpresa.ParamByName('id_empresa').AsString := AIDEmpresa;
  FQryEmpresa.Open;
end;

procedure TDM.AbrirReceber(const AIDEmpresa, AIDReceber, AParcela: string);
var
  LSql: string;
begin
  LSql := Concat(
    ' select r.id ', sl,
    '      , r.id_empresa ', sl,
    '      , r.id_pessoa ', sl,
    '      , r.data_lancamento as data_documento ', sl,
    '      , rd.id as id_titulo ', sl,
    '      , rd.parcela ', sl,
    '      , rd.data_vencimento ', sl,
    '      , rd.valor_parcela ', sl,
    '      , rd.valor_desconto ', sl,
    '      , rd.valor_juro ', sl,
    '      , rd.valor_total ', sl,
    '   from receber r ',
    '      , receber_detalhe rd ', sl,
    '  where rd.id_receber = r.id ', sl,
    '    and rd.data_pagamento is null ',sl,
    '    and rd.baixada    = ', Qt('N'), sl,
    '    and r.id          = :id_receber ', sl,
    '    and r.id_empresa  = :id_empresa ', sl,
    IfThen((not AParcela.Trim.IsEmpty) and (StrToInt(AParcela) > 0), '    and rd.parcela    = :parcela ', '')
  );

  FQryReceber.Close;
  FQryReceber.SQL.Text := LSql;
  FQryReceber.ParamByName('id_empresa').AsString := AIDEmpresa;
  FQryReceber.ParamByName('id_receber').AsString := AIDReceber;
  if (not AParcela.Trim.IsEmpty) and (StrToInt(AParcela) > 0) then
    FQryReceber.ParamByName('parcela').AsString  := AParcela;
  FQryReceber.Open;
end;

procedure TDM.ConfigurarBoleta;
var
  LDirLogo: string;
begin
  ACBrBoleto1.LayoutRemessa := c240;

  LDirLogo := ExtractFilePath(Application.ExeName) + 'Logos\Colorido\';
  if DirectoryExists(LDirLogo) then
    ACBrBoletoFCFortes1.DirLogo := LDirLogo;

  case FQryConfiguracao.FieldByName('layout_impressao').AsInteger of
    0: ACBrBoleto1.ACBrBoletoFC.LayOut := lPadrao;
    1: ACBrBoleto1.ACBrBoletoFC.LayOut := lCarne;
    2: ACBrBoleto1.ACBrBoletoFC.LayOut := lFatura;
    3: ACBrBoleto1.ACBrBoletoFC.LayOut := lPadraoEntrega;
    4: ACBrBoleto1.ACBrBoletoFC.LayOut := lReciboTopo;
    5: ACBrBoleto1.ACBrBoletoFC.LayOut := lPadraoEntrega2;
    6: ACBrBoleto1.ACBrBoletoFC.LayOut := lFaturaDetal;
    7: ACBrBoleto1.ACBrBoletoFC.LayOut := lTermica80mm;
  else
    ACBrBoleto1.ACBrBoletoFC.LayOut := lPadrao;
  end;

  case FQryConfiguracao.FieldByName('tipo_cobranca').AsInteger of
     0 : ACBrBoleto1.Banco.TipoCobranca := cobNenhum;
     1 : ACBrBoleto1.Banco.TipoCobranca := cobBancoDoBrasil;
     2 : ACBrBoleto1.Banco.TipoCobranca := cobSantander;
     3 : ACBrBoleto1.Banco.TipoCobranca := cobCaixaEconomica;
     4 : ACBrBoleto1.Banco.TipoCobranca := cobCaixaSicob;
     5 : ACBrBoleto1.Banco.TipoCobranca := cobBradesco;
     6 : ACBrBoleto1.Banco.TipoCobranca := cobItau;
     7 : ACBrBoleto1.Banco.TipoCobranca := cobBancoMercantil;
     8 : ACBrBoleto1.Banco.TipoCobranca := cobSicred;
     9 : ACBrBoleto1.Banco.TipoCobranca := cobBancoob;
    10 : ACBrBoleto1.Banco.TipoCobranca := cobBanrisul;
    11 : ACBrBoleto1.Banco.TipoCobranca := cobBanestes;
    12 : ACBrBoleto1.Banco.TipoCobranca := cobHSBC;
    13 : ACBrBoleto1.Banco.TipoCobranca := cobBancoDoNordeste;
    14 : ACBrBoleto1.Banco.TipoCobranca := cobBRB;
    15 : ACBrBoleto1.Banco.TipoCobranca := cobBicBanco;
    16 : ACBrBoleto1.Banco.TipoCobranca := cobBradescoSICOOB;
    17 : ACBrBoleto1.Banco.TipoCobranca := cobBancoSafra;
    18 : ACBrBoleto1.Banco.TipoCobranca := cobSafraBradesco;
    19 : ACBrBoleto1.Banco.TipoCobranca := cobBancoCECRED;
    20 : ACBrBoleto1.Banco.TipoCobranca := cobBancoDaAmazonia;
    21 : ACBrBoleto1.Banco.TipoCobranca := cobBancoDoBrasilSICOOB;
    22 : ACBrBoleto1.Banco.TipoCobranca := cobUniprime;
    23 : ACBrBoleto1.Banco.TipoCobranca := cobUnicredRS;
    24 : ACBrBoleto1.Banco.TipoCobranca := cobBanese;
    25 : ACBrBoleto1.Banco.TipoCobranca := cobCrediSIS;
    26 : ACBrBoleto1.Banco.TipoCobranca := cobUnicredES;
    27 : ACBrBoleto1.Banco.TipoCobranca := cobBancoCresolSCRS;
    28 : ACBrBoleto1.Banco.TipoCobranca := cobCitiBank;
    29 : ACBrBoleto1.Banco.TipoCobranca := cobBancoABCBrasil;
    30 : ACBrBoleto1.Banco.TipoCobranca := cobDaycoval;
    31 : ACBrBoleto1.Banco.TipoCobranca := cobUniprimeNortePR;
    32 : ACBrBoleto1.Banco.TipoCobranca := cobBancoPine;
    33 : ACBrBoleto1.Banco.TipoCobranca := cobBancoPineBradesco;
    34 : ACBrBoleto1.Banco.TipoCobranca := cobUnicredSC;
    35 : ACBrBoleto1.Banco.TipoCobranca := cobBancoAlfa;
    36 : ACBrBoleto1.Banco.TipoCobranca := cobBancoDoBrasilAPI;
    37 : ACBrBoleto1.Banco.TipoCobranca := cobBancoDoBrasilWS;
    38 : ACBrBoleto1.Banco.TipoCobranca := cobBancoCresol;
    39 : ACBrBoleto1.Banco.TipoCobranca := cobMoneyPlus;
    40 : ACBrBoleto1.Banco.TipoCobranca := cobBancoC6;
    41 : ACBrBoleto1.Banco.TipoCobranca := cobBancoRendimento;
    42 : ACBrBoleto1.Banco.TipoCobranca := cobBancoInter;
    43 : ACBrBoleto1.Banco.TipoCobranca := cobBancoSofisaSantander;
    44 : ACBrBoleto1.Banco.TipoCobranca := cobBS2;
    45 : ACBrBoleto1.Banco.TipoCobranca := cobPenseBankAPI;
    46 : ACBrBoleto1.Banco.TipoCobranca := cobBTGPactual;
  else
    ACBrBoleto1.Banco.TipoCobranca := cobNenhum;
  end;

  ACBrBoleto1.Cedente.Nome := FQryEmpresa.FieldByName('razao_social').AsString;

  if RemoveChar(FQryEmpresa.FieldByName('cnpj').AsString).Trim.Length = 11 then
    ACBrBoleto1.Cedente.TipoInscricao := pFisica
  else
    ACBrBoleto1.Cedente.TipoInscricao := pJuridica;

  ACBrBoleto1.Cedente.CNPJCPF       := RemoveChar(FQryEmpresa.FieldByName('cnpj').AsString);
  ACBrBoleto1.Cedente.CodigoCedente := FQryConfiguracao.FieldByName('codigo_cedente').AsString.Trim;
  ACBrBoleto1.Cedente.Convenio      := FQryConfiguracao.FieldByName('convenio').AsString.Trim;
  ACBrBoleto1.Cedente.Modalidade    := FQryConfiguracao.FieldByName('modalidade').AsString.Trim;
  ACBrBoleto1.Cedente.Agencia       := FQryConfiguracao.FieldByName('agencia_numero').AsString.Trim;
  ACBrBoleto1.Cedente.AgenciaDigito := FQryConfiguracao.FieldByName('agencia_digito').AsString.Trim;
  ACBrBoleto1.Cedente.Conta         := FQryConfiguracao.FieldByName('conta_numero').AsString.Trim;
  ACBrBoleto1.Cedente.ContaDigito   := FQryConfiguracao.FieldByName('conta_digito').AsString.Trim;
  ACBrBoleto1.Cedente.Logradouro    := FQryEmpresa.FieldByName('endereco').AsString;
  ACBrBoleto1.Cedente.Complemento   := FQryEmpresa.FieldByName('complemento').AsString;
  ACBrBoleto1.Cedente.Bairro        := FQryEmpresa.FieldByName('bairro').AsString;
  ACBrBoleto1.Cedente.Cidade        := FQryEmpresa.FieldByName('cidade').AsString;
  ACBrBoleto1.Cedente.CEP           := RemoveChar(FQryEmpresa.FieldByName('cep').AsString);
  ACBrBoleto1.Cedente.UF            := FQryEmpresa.FieldByName('uf').AsString;
  ACBrBoleto1.Cedente.Telefone      := RemoveChar(FQryEmpresa.FieldByName('telefone').AsString);

  ACBrBoleto1.DirArqRetorno         := ExtractFilePath(Application.ExeName);
  ACBrBoleto1.DirArqRemessa         := ExtractFilePath(Application.ExeName);

  if not DirectoryExists(ACBrBoleto1.DirArqRetorno) then
    raise Exception.Create('Diretório de Retorno não existe, favor verificar!' + sLineBreak + sLineBreak + ACBrBoleto1.DirArqRetorno);

  if not DirectoryExists(ACBrBoleto1.DirArqRemessa) then
    raise Exception.Create('Diretório de Remessa não existe, favor verificar!' + sLineBreak + sLineBreak + ACBrBoleto1.DirArqRemessa);
end;

procedure TDM.PrepararBoleto(const AIDEmpresa, AIDReceber, AParcela, GerarRemessa: string; var ADiretorio: string; var AArquivo: string);
var
  Titulo: TACBrTitulo;
  VQtdeCarcA, VQtdeCarcB, VQtdeCarcC :Integer;
  VLinha, logo : string;
  I: Integer;

  function RemoveChar(const Texto: string; strChar: string): string;
  var
    i: integer;
  begin
    Result := '';

    if (strChar = '') then
    begin
      for i := 1 to Length(Texto) do
      begin
        if (Texto[i] in ['0'..'9']) then
          Result := Result + Copy(Texto, i, 1);
      end;
    end
    else
    begin
      for i := 1 to Length(Texto) do
      begin
        if (Texto[i] <> strChar) then
          Result := Result + Copy(Texto, i, 1);
      end;
    end;
  end;

  function PreencherDir(aString: string; aCaracter: Char; aTamanho: integer): string;
  begin
    if Length(aString) > aTamanho then
      aString := Copy(aString, 0, aTamanho);

    Result := aString + StringOfChar(aCaracter, aTamanho - length(aString));
  end;

  function FormatarCNPJCPF(Numero: string): string;
  var
    i, Atual: integer;
  begin
    Numero := RemoveChar(Numero, '');

    case Length(Numero) of
      11: Result := '***.***.***-**';
      14: Result := '**.***.***/****-**';
      15: Result := '***.***.***/****-**';
    else
      Result := '**************';
    end;

    Numero := PreencherDir(Numero, ' ', Length(Result));

    Atual := 1;

    for i := 1 to Length(Result) do
    begin
      if (Result[i] = '*') and (Atual <= Length(Numero)) then
      begin
        Result[i] := Numero[Atual];
        Inc(Atual);
      end;
    end;
  end;

  function PathApp: string;
  begin
    Result := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0)));

    if not DirectoryExists(Result) then
      ForceDirectories(Result);
  end;

begin
  AbrirEmpresa(AIDEmpresa);

  AbrirReceber(AIDEmpresa, AIDReceber, AParcela);

  ConfigurarBoleta;

  ADiretorio := IncludeTrailingPathDelimiter(PathApp + 'BOLETO');
  if not DirectoryExists(ADiretorio) then
    ForceDirectories(ADiretorio);

  AArquivo := FQryReceber.FieldByName('id').AsString + '-boleto.pdf';

  ACBrBoleto1.ACBrBoletoFC.NomeArquivo := ADiretorio + AArquivo;

  ACBrBoleto1.ListadeBoletos.Clear;

  FQryReceber.First;
  while not FQryReceber.Eof do
  try
    Titulo:= ACBrBoleto1.CriarTituloNaLista;

    with Titulo do
    begin
      Carteira           := FQryConfiguracao.FieldByName('conta_carteira').AsString;
      NumeroDocumento    := PadRight(FQryReceber.FieldByName('id_titulo').AsString, 8, '0');
      if ACBrBoleto1.Banco.Numero = 1 then
        NossoNumero      := Carteira + FQryReceber.FieldByName('parcela').AsString
      else
        NossoNumero      := FQryReceber.FieldByName('parcela').AsString;

      DataProcessamento  := Now;
      DataDocumento      := FQryReceber.FieldByName('data_documento').AsDateTime;
      Vencimento         := FQryReceber.FieldByName('data_vencimento').AsDateTime;
      ValorDocumento     := FQryReceber.FieldByName('valor_total').AsCurrency;
      EspecieDoc         := 'DM';
      EspecieMod         := '';

      Aceite             := atNao;

      Sacado.NomeSacado  := FQryPessoa.FieldByName('nome').AsString;
      Sacado.CNPJCPF     := FormatarCNPJCPF(FQryPessoa.FieldByName('cpf_cnpj').AsString);
      Sacado.Logradouro  := FQryPessoa.FieldByName('endereco').AsString;
      Sacado.Numero      := FQryPessoa.FieldByName('numero').AsString;

      Sacado.Bairro      := FQryPessoa.FieldByName('bairro').AsString;
      Sacado.Cidade      := FQryPessoa.FieldByName('cidade').AsString;
      Sacado.UF          := FQryPessoa.FieldByName('uf').AsString;
      Sacado.CEP         := FQryPessoa.FieldByName('cep').AsString;
      Sacado.Complemento := FQryPessoa.FieldByName('complemento').AsString;

      {
      ValorDesconto      := qryConfiguracaovalor_desconto.Ascurrency;
      ValorMoraJuros     := qryConfiguracaovalor_mora.Ascurrency;
      ValorAbatimento    := qryConfiguracaovalor_deducao.AsCurrency;
      PercentualMulta    := 0.00;

      if qryConfiguracaovalor_mora.Ascurrency > 0 then
        DataMoraJuros     := Vencimento + 15;

      if qryConfiguracaovalor_desconto.Ascurrency > 0 then
        DataDesconto       := Vencimento - 10;

      if qryConfiguracaovalor_deducao.Ascurrency > 0 then
        DataAbatimento     := Vencimento - 15;

      if qryConfiguracaovalor_mora.Ascurrency > 0 then
        DataProtesto       := Vencimento + 20;
      }

      LocalPagamento     := FQryConfiguracao.FieldByName('local_pagamento').AsString;
      Mensagem.Text      := FQryConfiguracao.FieldByName('instrucao_ao_sacado').AsString;

      if not FQryConfiguracao.FieldByName('instrucao1').AsString.Trim.IsEmpty then
        Mensagem.Add(FQryConfiguracao.FieldByName('instrucao1').AsString);

      if not FQryConfiguracao.FieldByName('instrucao2').AsString.Trim.IsEmpty then
        Mensagem.Add(FQryConfiguracao.FieldByName('instrucao2').AsString);

      if not FQryConfiguracao.FieldByName('instrucao3').AsString.Trim.IsEmpty then
        Mensagem.Add(FQryConfiguracao.FieldByName('instrucao3').AsString);

      ACBrBoleto1.AdicionarMensagensPadroes(Titulo, Mensagem);

      if ACBrBoleto1.ACBrBoletoFC.LayOut = lFaturaDetal then
      begin
        for i:=0 to 3 do
        begin
          VLinha := '.';

          VQtdeCarcA := length('Descrição Produto/Serviço ' + IntToStr(I));
          VQtdeCarcB := Length('Valor:');
          VQtdeCarcC := 85 - (VQtdeCarcA + VQtdeCarcB);

          VLinha := PadLeft(VLinha,VQtdeCarcC,'.');

          Detalhamento.Add('Descrição Produto/Serviço ' +
            IntToStr(I) + ' '+ VLinha + ' Valor:   '+
            PadRight(FormatCurr('R$ ###,##0.00', FQryReceber.FieldByName('valor_total').AsCurrency * 0.25),18,' ') );
        end;
        Detalhamento.Add('');
        Detalhamento.Add('');
        Detalhamento.Add('');
        Detalhamento.Add('');
        Detalhamento.Add('Desconto ........................................................................... Valor: R$ 0,00' );
      end;
    end;

    if GerarRemessa.Trim.Equals('S') then
    begin
      FQryRemessa.Close;
      FQryRemessa.ParamByName('id_empresa').AsString := AIDEmpresa;
      FQryRemessa.ParamByName('id_receber').AsString := AIDReceber;
      FQryRemessa.ParamByName('parcela').AsString    := FQryReceber.FieldByName('parcela').Asstring;
      FQryRemessa.Open;
      if FQryRemessa.IsEmpty then
        FQryRemessa.Append
      else
        FQryRemessa.Edit;

      FQryRemessa.FieldByName('id_empresa').AsString      := AIDEmpresa;
      FQryRemessa.FieldByName('id_receber').AsString      := AIDReceber;
      FQryRemessa.FieldByName('parcela').AsString         := FQryReceber.FieldByName('parcela').AsString;
      FQryRemessa.FieldByName('dt_emissao').AsDateTime    := FQryReceber.FieldByName('data_documento').AsDateTime;
      FQryRemessa.FieldByName('dt_vencimento').AsDateTime := FQryReceber.FieldByName('data_vencimento').AsDateTime;
      FQryRemessa.FieldByName('valor').AsCurrency         := FQryReceber.FieldByName('valor_total').AsCurrency;
      FQryRemessa.FieldByName('cli_razaosocial').AsString := FQryPessoa.FieldByName('nome').AsString;
      FQryRemessa.FieldByName('cli_cpfcnpj').AsString     := OnlyNumber(FQryPessoa.FieldByName('cpf_cnpj').AsString);
      FQryRemessa.FieldByName('cli_endereco').AsString    := FQryPessoa.FieldByName('endereco').AsString;
      FQryRemessa.FieldByName('cli_numero').AsString      := FQryPessoa.FieldByName('numero').AsString;
      FQryRemessa.FieldByName('cli_bairro').AsString      := FQryPessoa.FieldByName('bairro').AsString;
      FQryRemessa.FieldByName('cli_cidade').AsString      := FQryPessoa.FieldByName('cidade').AsString;
      FQryRemessa.FieldByName('cli_uf').AsString          := FQryPessoa.FieldByName('uf').AsString;
      FQryRemessa.FieldByName('cli_cep').AsString         := OnlyNumber(FQryPessoa.FieldByName('cep').AsString);

      FQryRemessa.Post;
    end;
  finally
    FQryReceber.Next;
  end;
  ACBrBoleto1.GerarPDF;
end;

procedure TDM.ProcessaRetorno(const AMensagem: string; const ASucesso: Boolean;
  const ABase64: string);
begin

end;

function TDM.GerarBoleto(const AIDEmpresa, AIDReceber, AParcela: string): string;
var
  LDiretorio: string;
  LArquivo: string;
begin
  try
    try
      PrepararBoleto(AIDEmpresa, AIDReceber, AParcela, 'S', LDiretorio, LArquivo);

      ProcessaRetorno(
        'Boleto gerado com sucesso',
        True,
        TConverteArquivoBase64.Converter(LDiretorio + LArquivo)
      );
    except on E: Exception do
      ProcessaRetorno(E.Message, False);
    end;
  finally
    Result := FRetorno.Stringify;
  end;
end;

end.


