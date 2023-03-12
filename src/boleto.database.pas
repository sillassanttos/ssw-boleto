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
    ACBrBoleto: TACBrBoleto;
    ACBrBoletoFCFortes: TACBrBoletoFCFortes;
    ACBrExtenso: TACBrExtenso;
    ACBrMail: TACBrMail;
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
    function GetEnviarEmail(const AIDEmpresa, AIDREceber, AParcela, ADestino: string): string;
    function GerarRemessa(const AIDEmpresa, AIDRemessas: string): string;
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
  FRetorno := TJson.Create;

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

  FreeAndNil(FRetorno);
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
  ACBrMail.IsHTML   := False;
  ACBrMail.Host     := FQryConfiguracao.FieldByName('email_host').AsString.Trim;
  ACBrMail.Port     := FQryConfiguracao.FieldByName('email_porta').AsString.Trim;
  ACBrMail.Username := FQryConfiguracao.FieldByName('email_remetente').AsString.Trim;
  ACBrMail.Password := FQryConfiguracao.FieldByName('email_senha').AsString.Trim;
  ACBrMail.SetSSL   := FQryConfiguracao.FieldByName('email_ssl').AsString.Trim.Equals('S');
  ACBrMail.SetTLS   := FQryConfiguracao.FieldByName('email_tls').AsString.Trim.Equals('S');
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
      sl, '  where e.id = ', AIDEmpresa
    );
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
    '    and r.id          = ', AIDReceber, sl,
    '    and r.id_empresa  = ', AIDEmpresa, sl,
    IfThen((not AParcela.Trim.IsEmpty) and (StrToInt(AParcela) > 0), '    and rd.parcela = ' + AParcela, '')
  );

  FQryReceber.Close;
  FQryReceber.SQL.Text := LSql;
  FQryReceber.Open;
end;

procedure TDM.ConfigurarBoleta;
var
  LDirLogo: string;
begin
  ACBrBoleto.LayoutRemessa := c240;

  LDirLogo := ExtractFilePath(Application.ExeName) + 'Logos\Colorido\';
  if DirectoryExists(LDirLogo) then
    ACBrBoletoFCFortes.DirLogo := LDirLogo;

  case FQryConfiguracao.FieldByName('layout_impressao').AsInteger of
    0: ACBrBoleto.ACBrBoletoFC.LayOut := lPadrao;
    1: ACBrBoleto.ACBrBoletoFC.LayOut := lCarne;
    2: ACBrBoleto.ACBrBoletoFC.LayOut := lFatura;
    3: ACBrBoleto.ACBrBoletoFC.LayOut := lPadraoEntrega;
    4: ACBrBoleto.ACBrBoletoFC.LayOut := lReciboTopo;
    5: ACBrBoleto.ACBrBoletoFC.LayOut := lPadraoEntrega2;
    6: ACBrBoleto.ACBrBoletoFC.LayOut := lFaturaDetal;
    7: ACBrBoleto.ACBrBoletoFC.LayOut := lTermica80mm;
  else
    ACBrBoleto.ACBrBoletoFC.LayOut := lPadrao;
  end;

  case FQryConfiguracao.FieldByName('tipo_cobranca').AsInteger of
     0 : ACBrBoleto.Banco.TipoCobranca := cobNenhum;
     1 : ACBrBoleto.Banco.TipoCobranca := cobBancoDoBrasil;
     2 : ACBrBoleto.Banco.TipoCobranca := cobSantander;
     3 : ACBrBoleto.Banco.TipoCobranca := cobCaixaEconomica;
     4 : ACBrBoleto.Banco.TipoCobranca := cobCaixaSicob;
     5 : ACBrBoleto.Banco.TipoCobranca := cobBradesco;
     6 : ACBrBoleto.Banco.TipoCobranca := cobItau;
     7 : ACBrBoleto.Banco.TipoCobranca := cobBancoMercantil;
     8 : ACBrBoleto.Banco.TipoCobranca := cobSicred;
     9 : ACBrBoleto.Banco.TipoCobranca := cobBancoob;
    10 : ACBrBoleto.Banco.TipoCobranca := cobBanrisul;
    11 : ACBrBoleto.Banco.TipoCobranca := cobBanestes;
    12 : ACBrBoleto.Banco.TipoCobranca := cobHSBC;
    13 : ACBrBoleto.Banco.TipoCobranca := cobBancoDoNordeste;
    14 : ACBrBoleto.Banco.TipoCobranca := cobBRB;
    15 : ACBrBoleto.Banco.TipoCobranca := cobBicBanco;
    16 : ACBrBoleto.Banco.TipoCobranca := cobBradescoSICOOB;
    17 : ACBrBoleto.Banco.TipoCobranca := cobBancoSafra;
    18 : ACBrBoleto.Banco.TipoCobranca := cobSafraBradesco;
    19 : ACBrBoleto.Banco.TipoCobranca := cobBancoCECRED;
    20 : ACBrBoleto.Banco.TipoCobranca := cobBancoDaAmazonia;
    21 : ACBrBoleto.Banco.TipoCobranca := cobBancoDoBrasilSICOOB;
    22 : ACBrBoleto.Banco.TipoCobranca := cobUniprime;
    23 : ACBrBoleto.Banco.TipoCobranca := cobUnicredRS;
    24 : ACBrBoleto.Banco.TipoCobranca := cobBanese;
    25 : ACBrBoleto.Banco.TipoCobranca := cobCrediSIS;
    26 : ACBrBoleto.Banco.TipoCobranca := cobUnicredES;
    27 : ACBrBoleto.Banco.TipoCobranca := cobBancoCresolSCRS;
    28 : ACBrBoleto.Banco.TipoCobranca := cobCitiBank;
    29 : ACBrBoleto.Banco.TipoCobranca := cobBancoABCBrasil;
    30 : ACBrBoleto.Banco.TipoCobranca := cobDaycoval;
    31 : ACBrBoleto.Banco.TipoCobranca := cobUniprimeNortePR;
    32 : ACBrBoleto.Banco.TipoCobranca := cobBancoPine;
    33 : ACBrBoleto.Banco.TipoCobranca := cobBancoPineBradesco;
    34 : ACBrBoleto.Banco.TipoCobranca := cobUnicredSC;
    35 : ACBrBoleto.Banco.TipoCobranca := cobBancoAlfa;
    36 : ACBrBoleto.Banco.TipoCobranca := cobBancoDoBrasilAPI;
    37 : ACBrBoleto.Banco.TipoCobranca := cobBancoDoBrasilWS;
    38 : ACBrBoleto.Banco.TipoCobranca := cobBancoCresol;
    39 : ACBrBoleto.Banco.TipoCobranca := cobMoneyPlus;
    40 : ACBrBoleto.Banco.TipoCobranca := cobBancoC6;
    41 : ACBrBoleto.Banco.TipoCobranca := cobBancoRendimento;
    42 : ACBrBoleto.Banco.TipoCobranca := cobBancoInter;
    43 : ACBrBoleto.Banco.TipoCobranca := cobBancoSofisaSantander;
    44 : ACBrBoleto.Banco.TipoCobranca := cobBS2;
    45 : ACBrBoleto.Banco.TipoCobranca := cobPenseBankAPI;
    46 : ACBrBoleto.Banco.TipoCobranca := cobBTGPactual;
  else
    ACBrBoleto.Banco.TipoCobranca := cobNenhum;
  end;

  ACBrBoleto.Cedente.Nome := FQryEmpresa.FieldByName('razao_social').AsString;

  if RemoveChar(FQryEmpresa.FieldByName('cnpj').AsString).Trim.Length = 11 then
    ACBrBoleto.Cedente.TipoInscricao := pFisica
  else
    ACBrBoleto.Cedente.TipoInscricao := pJuridica;

  ACBrBoleto.Cedente.CNPJCPF       := RemoveChar(FQryEmpresa.FieldByName('cnpj').AsString);
  ACBrBoleto.Cedente.CodigoCedente := FQryConfiguracao.FieldByName('codigo_cedente').AsString.Trim;
  ACBrBoleto.Cedente.Convenio      := FQryConfiguracao.FieldByName('convenio').AsString.Trim;
  ACBrBoleto.Cedente.Modalidade    := FQryConfiguracao.FieldByName('modalidade').AsString.Trim;
  ACBrBoleto.Cedente.Agencia       := FQryConfiguracao.FieldByName('agencia_numero').AsString.Trim;
  ACBrBoleto.Cedente.AgenciaDigito := FQryConfiguracao.FieldByName('agencia_digito').AsString.Trim;
  ACBrBoleto.Cedente.Conta         := FQryConfiguracao.FieldByName('conta_numero').AsString.Trim;
  ACBrBoleto.Cedente.ContaDigito   := FQryConfiguracao.FieldByName('conta_digito').AsString.Trim;
  ACBrBoleto.Cedente.Logradouro    := FQryEmpresa.FieldByName('endereco').AsString;
  ACBrBoleto.Cedente.Complemento   := FQryEmpresa.FieldByName('complemento').AsString;
  ACBrBoleto.Cedente.Bairro        := FQryEmpresa.FieldByName('bairro').AsString;
  ACBrBoleto.Cedente.Cidade        := FQryEmpresa.FieldByName('cidade').AsString;
  ACBrBoleto.Cedente.CEP           := RemoveChar(FQryEmpresa.FieldByName('cep').AsString);
  ACBrBoleto.Cedente.UF            := FQryEmpresa.FieldByName('uf').AsString;
  ACBrBoleto.Cedente.Telefone      := RemoveChar(FQryEmpresa.FieldByName('telefone').AsString);

  ACBrBoleto.DirArqRetorno         := ExtractFilePath(Application.ExeName);
  ACBrBoleto.DirArqRemessa         := ExtractFilePath(Application.ExeName);

  if not DirectoryExists(ACBrBoleto.DirArqRetorno) then
    raise Exception.Create('Diretório de Retorno não existe, favor verificar!' + sLineBreak + sLineBreak + ACBrBoleto.DirArqRetorno);

  if not DirectoryExists(ACBrBoleto.DirArqRemessa) then
    raise Exception.Create('Diretório de Remessa não existe, favor verificar!' + sLineBreak + sLineBreak + ACBrBoleto.DirArqRemessa);
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

  ACBrBoleto.ACBrBoletoFC.NomeArquivo := ADiretorio + AArquivo;

  ACBrBoleto.ListadeBoletos.Clear;

  FQryReceber.First;
  while not FQryReceber.Eof do
  try
    Titulo:= ACBrBoleto.CriarTituloNaLista;

    with Titulo do
    begin
      Carteira           := FQryConfiguracao.FieldByName('conta_carteira').AsString;
      NumeroDocumento    := PadRight(FQryReceber.FieldByName('id_titulo').AsString, 8, '0');
      if ACBrBoleto.Banco.Numero = 1 then
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

      LocalPagamento     := FQryConfiguracao.FieldByName('local_pagamento').AsString;
      Mensagem.Text      := FQryConfiguracao.FieldByName('instrucao_ao_sacado').AsString;

      if not FQryConfiguracao.FieldByName('instrucao1').AsString.Trim.IsEmpty then
        Mensagem.Add(FQryConfiguracao.FieldByName('instrucao1').AsString);

      if not FQryConfiguracao.FieldByName('instrucao2').AsString.Trim.IsEmpty then
        Mensagem.Add(FQryConfiguracao.FieldByName('instrucao2').AsString);

      if not FQryConfiguracao.FieldByName('instrucao3').AsString.Trim.IsEmpty then
        Mensagem.Add(FQryConfiguracao.FieldByName('instrucao3').AsString);

      ACBrBoleto.AdicionarMensagensPadroes(Titulo, Mensagem);

      if ACBrBoleto.ACBrBoletoFC.LayOut = lFaturaDetal then
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
      FQryRemessa.SQL.Text :=
        Concat(
          sl, ' select * ',
          sl, '   from remessa ',
          sl, '  where id_empresa = ', AIDEmpresa,
          sl, '    and id_receber = ', AIDReceber,
          sl, '    and parcela    = ', FQryReceber.FieldByName('parcela').Asstring
        );

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
  ACBrBoleto.GerarPDF;
end;

procedure TDM.ProcessaRetorno(const AMensagem: string; const ASucesso: Boolean; const ABase64: string);
begin
  FRetorno.Clear;

  FRetorno.Put('sucesso' , ASucesso);
  FRetorno.Put('mensagem', AMensagem);

  if not ABase64.Trim.IsEmpty then
    FRetorno.Put('fileBS64', ABase64);
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

function TDM.GetEnviarEmail(const AIDEmpresa, AIDREceber, AParcela, ADestino: string): string;
var
  LCopiaEmail: TStringList;
  LCorpoMensagem: TStringList;

  LNomeEmitente: string;
  LAssuntoMensagem: string;
  LDiretorio: string;
  LArquivo: string;
begin
  try
    try
      PrepararBoleto(AIDEmpresa, AIDReceber, AParcela, 'N', LDiretorio, LArquivo);

      if ADestino.Trim.IsEmpty then
        raise Exception.Create('Destinatário da mensagem não informado.');

      LCopiaEmail := TStringList.Create;
      try
        try
          LCorpoMensagem := TStringList.Create;
          try
            LCorpoMensagem := TStringList.Create;
            LCorpoMensagem.Clear;

            ACBrBoleto.EnviarEmail(ADestino ,'Envio de Boleto', LCorpoMensagem, True);

            ProcessaRetorno('Email enviado com sucesso');
          finally
            LCorpoMensagem.Free;
          end;
        except on E: Exception do
          raise Exception.Create(PWideChar('Erro ao enviar e-mail: ' + sl + E.Message));
        end;
      finally
        LCopiaEmail.Free;
      end;
    except on E: Exception do
      ProcessaRetorno(E.Message, False);
    end;
  finally
    Result := FRetorno.Stringify;
  end;
end;

function TDM.GerarRemessa(const AIDEmpresa, AIDRemessas: string): string;
var
  LTitulo: TACBrTitulo;

  LArquivoRemessa: string;

  LRemessa: Integer;

  LDataProcessamento: TDateTime;

  LQryPesquisa: TZQuery;
begin
  try
    LQryPesquisa := CriarQuery;
    try
      AbrirEmpresa(AIDEmpresa);

      ConfigurarBoleta;

      LQryPesquisa.Close;
      LQryPesquisa.SQL.Text :=
        Concat(
          sl, ' select r.id ',
          sl, '      , r.id_empresa ',
          sl, '      , r.id_receber ',
          sl, '      , d.id as id_titulo ',
          sl, '      , r.parcela ',
          sl, '      , r.dt_emissao ',
          sl, '      , r.dt_vencimento ',
          sl, '      , r.valor ',
          sl, '      , r.cli_razaosocial ',
          sl, '      , r.cli_cpfcnpj ',
          sl, '      , r.cli_endereco ',
          sl, '      , r.cli_numero ',
          sl, '      , r.cli_bairro ',
          sl, '      , r.cli_cidade ',
          sl, '      , r.cli_uf ',
          sl, '      , r.cli_cep ',
          sl, '      , r.dt_pagamento ',
          sl, '      , r.cancelamento_loja ',
          sl, '      , r.pagamento_loja ',
          sl, '      , r.alteracao_loja ',
          sl, '      , r.selecionada ',
          sl, '   from remessa r ',
          sl, '      , receber_detalhe d ',
          sl, '  where d.id_receber = r.id_receber ',
          sl, '    and d.parcela  = r.parcela ',
          sl, '    and r.id_empresa = ', AIDEmpresa,
          sl, '    and r.id in (', AIDRemessas, ') '
        );
      LQryPesquisa.Open;
      LQryPesquisa.FetchAll;

      if LQryPesquisa.IsEmpty then
        raise Exception.Create('Nenhum registro encontrado com os parametros informados!');

      LRemessa := StrToInt(FormatDateTime('yyyymmdd', Now));

      ACBrBoleto.NomeArqRemessa := Concat('rem', LRemessa.ToString, '.rem');

      LDataProcessamento := Now;

      ACBrBoleto.ListadeBoletos.Clear;

      LQryPesquisa.First;
      while not LQryPesquisa.Eof do
      try
        LTitulo := ACBrBoleto.CriarTituloNaLista;
        with LTitulo do
        begin
          OcorrenciaOriginal.Tipo := toRemessaRegistrar;
          Vencimento              := LQryPesquisa.FieldByName('dt_vencimento').AsDateTime;
          DataDocumento           := LQryPesquisa.FieldByName('dt_emissao').AsDateTime;
          NumeroDocumento         := LQryPesquisa.FieldByName('id_titulo').AsString;
          EspecieDoc              := '';
          Aceite                  := atSim;
          DataProcessamento       := LDataProcessamento;
          Carteira                := FQryConfiguracao.FieldByName('conta_carteira').AsString;

          if ACBrBoleto.Banco.Numero = 1 then
            NossoNumero           := Carteira + LQryPesquisa.FieldByName('parcela').AsString
          else
            NossoNumero           := LQryPesquisa.FieldByName('parcela').AsString;

          ValorDocumento          := LQryPesquisa.FieldByName('valor').AsCurrency;
          Sacado.NomeSacado       := LQryPesquisa.FieldByName('cli_razaosocial').AsString;

          case LQryPesquisa.FieldByName('cli_cpfcnpj').AsString.Trim.Length of
            11 : Sacado.Pessoa    := pFisica;
            14 : Sacado.Pessoa    := pJuridica;
          else
            raise Exception.Create(
              Concat(
                'Erro com CPF/CNPJ Cliente: ',  sl,
                LQryPesquisa.FieldByName('cli_cpfcnpj').AsString, ' | ',
                LQryPesquisa.FieldByName('cli_razaosocial').AsString
              )
            );
          end;

          Sacado.CNPJCPF          := RemoveChar(LQryPesquisa.FieldByName('cli_cpfcnpj').AsString);
          Sacado.Logradouro       := LQryPesquisa.FieldByName('cli_endereco').AsString;
          Sacado.Numero           := LQryPesquisa.FieldByName('cli_numero').AsString;
          Sacado.Bairro           := LQryPesquisa.FieldByName('cli_bairro').AsString;
          Sacado.Cidade           := LQryPesquisa.FieldByName('cli_cidade').AsString;
          Sacado.UF               := LQryPesquisa.FieldByName('cli_uf').AsString;
          Sacado.CEP              := RemoveChar(LQryPesquisa.FieldByName('cli_cep').AsString);
          LocalPagamento          := FQryConfiguracao.FieldByName('local_pagamento').AsString;
          ValorAbatimento         := 0.00;
          ValorMoraJuros          := 0.00;
          ValorDesconto           := 0.00;
          ValorAbatimento         := 0.00;
          DataMoraJuros           := 0.00;
          DataDesconto            := 0.00;
          DataAbatimento          := 0.00;
          DataProtesto            := 0.00;
          PercentualMulta         := 0.00;
          Mensagem.Text           := FQryConfiguracao.FieldByName('instrucao_ao_sacado').AsString;
          OcorrenciaOriginal.Tipo := toRemessaRegistrar;
          Instrucao1              := PadRight(trim(FQryConfiguracao.FieldByName('instrucao1').AsString), 2, '0');
          Instrucao2              := PadRight(trim(FQryConfiguracao.FieldByName('instrucao2').AsString), 2, '0');
        end;

        FQryReceberDetalhe.Close;
        FQryReceberDetalhe.SQL.Text :=
          Concat(
            sl, ' select * ',
            sl, '   from receber_detalhe ',
            sl, '  where id = ', LQryPesquisa.FieldByName('id_titulo').AsString
          );
        FQryReceberDetalhe.Open;

        FQryReceberDetalhe.Edit;
        FQryReceberDetalhe.FieldByName('remessa_gerada').AsString := 'S';
        FQryReceberDetalhe.FieldByName('boleto_gerado').AsString  := 'S';
        FQryReceberDetalhe.Post;
      finally
        LQryPesquisa.Next;
      end;

      LArquivoRemessa := ACBrBoleto.GerarRemessa(LRemessa);

      LQryPesquisa.Close;
      LQryPesquisa.SQL.Text :=
        Concat(
          sl, ' delete ',
          sl, '   from remessa ',
          sl, '  where id_empresa = ', AIDEmpresa,
          sl, '    and id in (', AIDRemessas, ') '
        );
      LQryPesquisa.ExecSQL;

      ProcessaRetorno('Remessa gerada com sucesso', True, TConverteArquivoBase64.Converter(LArquivoRemessa));
    except
      on E: Exception do
      begin
        ProcessaRetorno(E.Message, False);
      end;
    end;
  finally
    FreeAndNil(LQryPesquisa);

    Result := FRetorno.Stringify;
  end;
end;

end.


