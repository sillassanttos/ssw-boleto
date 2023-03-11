unit boleto.database;

{$MODE DELPHI}{$H+}

interface

uses
  Classes,
  SysUtils,
  ZConnection;

type

  { TDM }

  TDM = class(TDataModule)
    Conexao: TZConnection;
  private

  public

  end;

var
  DM: TDM;

implementation

{$R *.lfm}

end.

