(*============================================================================
| cfg.pas
|   read config file for defaults.
|
| History:
| Date       Author     Comment
| ----       ------     -------
| -- --- 94  G. Ollis	 created and developed program
============================================================================*)

{$I-}
{$PACKRECORDS 1}

Unit CFG;

INTERFACE

Uses VCrt;

Const
  {Mouse Constants}

  DefLeftButton=0;
  DefRightButton=1;
  DefCenterButton=2;
  DefMousePresent=FALSE;

Var
  LeftButton,  {Mouse setup}
  RightButton,
  CenterButton,

  SaveTextAttr:Byte;
  MousePresent:Boolean;

Const
  CFGFile='hexed.cfg';

{++PROCEDURES++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}
{++FUNCTIONS+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}

Function HelpDir:String;
Function CheckOverflow(C:Char; P:Pointer):Boolean;

{++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}

IMPLEMENTATION

Uses Dos,Ollis,CNT,VConvert,VOCTool,CMFTool;

Type
  Exclusive=Array [1..10] Of Byte;
  ExclusionType=Record
    D:Array [1..20] Of Exclusive;
    Num:Byte;
  End;

Var
  ExcludeReal:ExclusionType;
  ExcludeSing:ExclusionType;
  ExcludeDoub:ExclusionType;
  ExcludeExte:ExclusionType;
  ExcludeComp:ExclusionType;

{------------------------------------------------------------------------}
{FSplit}
Function HelpDir:String;
Var Path: PathStr; var Dir: DirStr; var Name: NameStr;
   var Ext: ExtStr;
Begin
  Path:=ParamStr(0);
  FSplit(Path,Dir,Name,Ext);
  If (Dir<>'') And (Dir[Length(Dir)] In AllowDirectorySeparators) Then
    Delete(Dir,Length(Dir),1);
  HelpDir:=Dir;
End;

{----------------------------------------------------------------------}

Function CheckOverflow(C:Char; P:Pointer):Boolean;
Var E2:^Exclusive;     { file fragment}
    E1:^ExclusionType; { exclude what? }
    I:Integer;
Begin
  Case UpCase(C) Of
    'R' : E1:=@ExcludeReal;
    'S' : E1:=@ExcludeSing;
    'D' : E1:=@ExcludeDoub;
    'X' : E1:=@ExcludeExte;
    'C' : E1:=@ExcludeComp;
  End;
  CheckOverflow:=False;
  E2:=P;
  For I:=1 To E1^.Num Do
    If ((E1^.D[I,1]=E2^[1]) Or (E1^.D[I,1]=0)) And
       ((E1^.D[I,2]=E2^[2]) Or (E1^.D[I,2]=0)) And
       ((E1^.D[I,3]=E2^[3]) Or (E1^.D[I,3]=0)) And
       ((E1^.D[I,4]=E2^[4]) Or (E1^.D[I,4]=0)) And
       ((E1^.D[I,5]=E2^[5]) Or (E1^.D[I,5]=0)) And
       ((E1^.D[I,6]=E2^[6]) Or (E1^.D[I,6]=0)) And
       ((E1^.D[I,7]=E2^[7]) Or (E1^.D[I,7]=0)) And
       ((E1^.D[I,8]=E2^[8]) Or (E1^.D[I,8]=0)) And
       ((E1^.D[I,9]=E2^[9]) Or (E1^.D[I,9]=0)) And
       ((E1^.D[I,10]=E2^[10]) Or (E1^.D[I,10]=0)) Then
      Begin
        CheckOverflow:=True;
        Exit;
      End;
End;

{----------------------------------------------------------------------}

Var
  Buff:^String;

Function GetString(Var F:Text):String;
Var
  S:String;
  I:Integer;
Begin
  {skip over runs of blanks (hexed.cfg has "SET RTBTN  1", which used to
   come out as an empty word, i.e. button 0)}
  While (Buff^<>'') And (Buff^[1] In [' ',#9]) Do
    Delete(Buff^,1,1);
  If Buff^='' Then
    Readln(F,Buff^);

  I:=1;
  S:='';
  While (Buff^[I]<>' ') And (I<=Length(Buff^)) Do
    Begin
      S:=S+Buff^[I];
      Inc(I);
    End;

  Delete(Buff^,1,I);

  GetString:=S;
End;

{----------------------------------------------------------------------}

Function GetByte(Var F:TEXT):Byte;
Begin
  GetByte:=StrToInt(GetString(F));
End;

{----------------------------------------------------------------------}

Function UpString(S:String):String;
Var I:Integer;
Begin
  For I:=1 To Length(S) Do
    S[I]:=UpCase(S[I]);
  UpString:=S;
End;

{----------------------------------------------------------------------}

Procedure StOverflow(Var F:Text);
Var S:String; I:Integer;
Begin
  S:=UpString(GetString(F));
  If S='REAL' Then
    If ExcludeReal.Num<19 Then
      Begin
        Inc(ExcludeReal.Num);
        For I:=1 To 10 Do
          ExcludeReal.D[ExcludeReal.Num,I]:=GetByte(F);
      End
    Else
      Begin
        Write('Too many real exclusions');
        Repeat Until Readkey=#13;
        Writeln('.');
      End;

  If S='SING' Then
    If ExcludeSing.Num<19 Then
      Begin
        Inc(ExcludeSing.Num);
        For I:=1 To 10 Do
          ExcludeSing.D[ExcludeSing.Num,I]:=GetByte(F);
      End
    Else
      Begin
        Write('Too many single exclusions');
        Repeat Until Readkey=#13;
        Writeln('.');
      End;

  If S='DOUB' Then
    If ExcludeDoub.Num<19 Then
      Begin
        Inc(ExcludeDoub.Num);
        For I:=1 To 10 Do
          ExcludeDoub.D[ExcludeDoub.Num,I]:=GetByte(F);
      End
    Else
      Begin
        Write('Too many Double exclusions');
        Repeat Until Readkey=#13;
        Writeln('.');
      End;

  If S='EXTE' Then
    If ExcludeExte.Num<19 Then
      Begin
        Inc(ExcludeExte.Num);
        For I:=1 To 10 Do
          ExcludeExte.D[ExcludeExte.Num,I]:=GetByte(F);
      End
    Else
      Begin
        Write('Too many extended exclusions');
        Repeat Until Readkey=#13;
        Writeln('.');
      End;

  If S='COMP' Then
    If ExcludeComp.Num<19 Then
      Begin
        Inc(ExcludeComp.Num);
        For I:=1 To 10 Do
          ExcludeComp.D[ExcludeComp.Num,I]:=GetByte(F);
      End
    Else
      Begin
        Write('Too many comp exclusions');
        Repeat Until Readkey=#13;
        Writeln('.');
      End;

  Buff^:='';
End;

{----------------------------------------------------------------------}

Procedure ReadCFGFile(FileName:String);
Var F:Text; S:String;  Line:Integer;
Begin
  LeftButton:=DefLeftButton;
  RightButton:=DefRightButton;
  CenterButton:=DefCenterButton;
  MousePresent:=DefMousePresent;

  ExcludeReal.Num:=0;
  ExcludeSing.Num:=0;
  ExcludeDoub.Num:=0;
  ExcludeExte.Num:=0;
  ExcludeComp.Num:=0;
  Line:=1;
  If HelpDir='' Then
    Assign(F,FileName)
  Else
    Assign(F,HelpDir+DirectorySeparator+FileName);
  Reset(F);
  If IOResult<>0 Then
    Exit;
  While Not EOF(F) Do
    Begin
      Repeat
        S:=UpString(GetString(F));
      Until (S<>'') Or (EOF(F));
      If (S[1]=';') Then
        Buff^:=''
      Else If S='SET' Then
        Begin
          S:=UpString(GetString(F));
          If S='OVERFLOW' Then
            StOverflow(F)
          Else If S='LFTBTN' Then
            Begin
              LeftButton:=GetByte(F);
              Buff^:='';
            End
          Else If S='CNTBTN' Then
            Begin
              CenterButton:=GetByte(F);
              Buff^:='';
            End
          Else If S='RTBTN' Then
            Begin
              RightButton:=GetByte(F);
              Buff^:='';
            End
          Else
            Begin
              WriteContactMsg;
              TextAttr:=LightGray;
              Writeln('Set command not known line #',line);
              Writeln('SET ',S);
              Halt;
            End;
        End
      Else If S='INIT' Then
        Begin
          S:=UpString(GetString(F));
          If S='MOUSE' Then
            Begin
              If InitMC Then
                Begin
                  MousePresent:=True;
                  ShowMC;
                End;
            End
          Else If S='SB' Then
            Begin
              S:=UpString(GetString(F));
              If S='DIGITAL' Then
                InitVocSB
              Else IF S='FM' Then
                InitCMFSB
              Else
                Begin
                  WriteContactMsg;
                  TextAttr:=LightGray;
                  Writeln('sound blaster initalization unknown.');
                  Writeln('INIT SB ',S);
                End;
            End
          Else
            Begin
              WriteContactMsg;
              TextAttr:=LightGray;
              Writeln('hardware initalization unknown.');
              Writeln('INIT ',S);
              Halt;
            End;
          Buff^:='';
        End
      Else
        Begin
          WriteContactMsg;
          TextAttr:=LightGray;
          Writeln('Configuration File error line #',line);
          Writeln(S);
          Halt;
        End;
      Line:=Line+1;
    End;
  Close(F);
End;

{======================================================================}

Begin
  New(Buff);
  Buff^:='';
  ReadCFGFile(CFGFile);
  Dispose(Buff);
End.
