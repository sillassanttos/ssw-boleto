program boleto;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  {$IFDEF HASAMIGA}
  athreads,
  {$ENDIF}
  Interfaces,
  Forms,
  indylaz,
  boleto.view.principal,
  boleto.util.converte.arquivo.base64,
  boleto.util.biblioteca;

{$R *.res}

begin
  RequireDerivedFormResource:=True;
  Application.Scaled:=True;
  Application.Initialize;
  Application.CreateForm(TPrincipalView, PrincipalView);
  Application.Run;
end.

