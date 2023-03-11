unit boleto.database;

{$MODE DELPHI}{$H+}

interface

uses
  Classes,
  SysUtils,
  IniFiles,
  ZConnection;

type

  { TDM }

  TDM = class(TDataModule)
    Conexao: TZConnection;
    procedure ConexaoBeforeConnect(Sender: TObject);
    procedure DataModuleCreate(Sender: TObject);
  private

  public

  end;

var
  DM: TDM;

implementation

{$R *.lfm}

{ TDM }

procedure TDM.DataModuleCreate(Sender: TObject);
begin

end;

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

end.


