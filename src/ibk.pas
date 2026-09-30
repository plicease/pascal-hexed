(*============================================================================
| ibk.pas
|   ibk formal apl.  ibk is creative's instrument bank format and is pretty
|   useless 100% of the time.
|
| History:
| Date       Author     Comment
| ----       ------     -------
| -- --- 94  G. Ollis	 created and developed program
============================================================================*)

{$PACKRECORDS 1}

Unit IBK;

INTERFACE

Type
  InstrumentType=Array [$0..$F] Of Byte;
  IBKInstrumentName=Array [$0..$8] Of Char;
  SBIInstrumentName=Array [5..36] Of Char;
  IDType=Array [$0..$3] Of Char;

  SBIType=Record
    ID:IDType;
    Name:SBIInstrumentName;
    Data:InstrumentType;
  End;
  SBIFile=FILE of SBIType;

  IBKType=Record
    ID:IDType;
    Data:Array [1..128] Of InstrumentType;
    Name:Array [1..128] Of IBKInstrumentName;
  End;
  IBKFile=FILE of IBKType;

Const
  IBKID:IDType='IBK'#$1A;
  SBIID:IDType='SBI'#$1A;

IMPLEMENTATION

End.
