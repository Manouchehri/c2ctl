{
   c2ctl -- Intel Core (2) frequency and voltage modification utility
   Copyright (C) 2009 Stefan Ziegenbalg
   http://www.ztex.de

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License version 3 as
   published by the Free Software Foundation.

   This program is distributed in the hope that it will be useful, but
   WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
   General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program; if not, see http://www.gnu.org/licenses/.
}

{$mode objfpc}
uses
{$ifdef VER2}
  oldlinux,
{$else}
  linux,
{$endif}  
  errors;

const perf_state  = $198;
      perf_ctl    = $199;
      misc_enable = $1a0;
//      eist_mask   = 17;
      eist_mask   = 1;

type TMsrBuf = array[0..7] of byte;
      

procedure error(msg:ansistring);
begin
writeln(stderr,msg);
halt(2);
end;


function int2str(i:longint):string[15];
begin
str(i,int2str);
end;

function val2(const s:shortstring; var d:longint):boolean;
var i,r  : longint;
begin
val(s,r,i);
result:=i=0;
if result then d:=r;
end;



procedure rdmsr(fd:longint; msr:dword; var buf:TMsrBuf);
begin
if fdseek(fd, msr, seek_set)<>longint(msr) then error('Error seeking to MSR '+hexstr(msr,8)+': '+StrError(linuxerror) );
if fdread(fd,buf,8)<>8 then error('Error reading MSR '+hexstr(msr,8)+': '+StrError(linuxerror) );
end;


procedure wrmsr(fd:longint; msr:dword; var buf:TMsrBuf);
begin
if fdseek(fd, msr, seek_set)<>longint(msr) then error('Error seeking to MSR '+hexstr(msr,8)+': '+StrError(linuxerror) );
if fdwrite(fd,buf,8)<>8 then error('Error writing to MSR '+hexstr(msr,8)+': '+StrError(linuxerror) );
end;


procedure paramerr(msg: ansistring);
begin
if msg<>'' then 
  begin
  writeln(stderr,msg);
  writeln(stderr);
  end;
writeln(stderr,'Warning:');
writeln(stderr,'  USE THIS PROGRAM AT YOU OWN RISK. IT MAY DAMAGE YOUR HARDWARE.');
writeln(stderr);
writeln(stderr,'Usage: ');
writeln(stderr,'  c2ctl <cpu>[-<cpun>]                Print some information about CPU(s) <cpu>(-<cpun>)');
writeln(stderr,'  c2ctl <cpu>[-<cpun>] <fid> <vid>    Set fid and vid for CPU(s) <cpu>(-<cpun>) and enable EIST if necessary');
writeln(stderr,'  c2ctl <cpu>[-<cpun>] -e             Enable EIST for CPU(s) <cpu>(-<cpun>)');
writeln(stderr,'  c2ctl <cpu> -a                      Print DSDT template for CPU <cpu> using the current settings');
writeln(stderr,'  c2ctl -h                            This help');
writeln(stderr);
writeln(stderr,'Examples: ');
writeln(stderr,'  c2ctl 0-3 8 32                      Set fid=8 and vid=32 for CPUs 0-3');
writeln(stderr,'  c2ctl 0 -a                          Print a DSDT template for CPU 0');
if msg<>'' then halt(1);
halt(0);
end;


procedure val3(const s:shortstring; var d:longint);
var i : longint;
begin
val(s,d,i);
if i<>0 then paramerr('Number expected: `'+s+'''');
end;

procedure val3(const s:shortstring; var d:longint; max:longint);
var i  : longint;
begin
val(s,d,i);
if (i<>0) or (d<0) or (d>max) then paramerr('Number between 0 and '+int2str(max)+' expected: `'+s+'''');
end;


procedure info(fd:longint);
var buf1,buf2  : TMSRBuf;
begin
rdmsr(fd, perf_state, buf1);
rdmsr(fd, perf_ctl, buf2);
writeln('      Current  Target    Min.    Max.');
writeln('FID: ', buf1[1]:8, buf2[1]:8, buf1[7]:8, buf1[5]:8);
writeln('VID: ', buf1[0]:8, buf2[0]:8, buf1[6]:8, buf1[4]:8);
//writeln(buf1[0],' ',buf1[1],'  ',buf1[2],' ',buf1[3],'    ',buf1[4],' ',buf1[5],'  ',buf1[6],' ',buf1[7]);
//writeln(buf2[0],' ',buf2[1],'  ',buf2[2],' ',buf2[3],'    ',buf2[4],' ',buf2[5],'  ',buf2[6],' ',buf2[7]);
rdmsr(fd, misc_enable, buf1);
writeln('ESIT_ENABLE = ',(buf1[2] and 1)<>0,'    ESIT_LOCK = ',(buf1[2] and 16)<>0);
end;


procedure DSDTInfo(fd:longint);
var buf  : TMSRBuf;
begin
rdmsr(fd, perf_state, buf);
writeln('	{');
writeln('            Name (_PPC, 0x00)');
writeln;
writeln('            Name (_PCT, Package (0x02)');
writeln('            {');
writeln('                ResourceTemplate ()');
writeln('                {');
writeln('                    Register (FFixedHW, 	// PERF_CTL');
writeln('                        0x10,              	// Bit Width');
writeln('                        0x00,               	// Bit Offset');
writeln('                        0x',hexstr(perf_ctl,8),' 		// Address');
writeln('                        ,)');
writeln('                },');
writeln;
writeln('                ResourceTemplate ()');
writeln('                {');
writeln('                    Register (FFixedHW, 	// PERF_STATUS');
writeln('                        0x10,	               	// Bit Width');
writeln('                        0x00,    		// Bit Offset');
writeln('                        0x',hexstr(perf_state,8),', 		// Address');
writeln('                        ,)');
writeln('                }');
writeln('            })');
writeln;
writeln('            Name (_PSS, Package (0x01)');
writeln('            {');
writeln('                Package (0x06)');
writeln('                {');
writeln('                    3000, 		// f in MHz');
writeln('                    75000, 		// P in mW');
writeln('                    10, 		// Transition latency in us');
writeln('                    10, 		// Bus Master latency in us');
writeln('                    0x0000',hexstr(buf[1],2),hexstr(buf[0],2),' 		// value written to PERF_CTL; fid=',buf[1],', vid=',buf[0]);
writeln('                    0x0000',hexstr(buf[1],2),hexstr(buf[0],2),' 		// value of PERF_STATE after successful transition; fid=',buf[1],', vid=',buf[0]);
writeln('                }');
writeln('            })');
writeln('	}');
writeln(stderr,'Please edit frequency and power dissipation by hand.');
end;


procedure enableEIST(fd:longint; force:boolean);
var buf : TMSRBuf;
begin
rdmsr(fd, misc_enable, buf);
if force or (buf[2] and eist_mask<>eist_mask) then
  begin
  buf[2]:=buf[2] or eist_mask;
  wrmsr(fd, misc_enable, buf);
  end;
//rdmsr(fd, perf_state
end;


procedure setFidVid(fd, fid, vid:longint);
var buf : TMSRBuf;
begin
enableEIST(fd,false);
rdmsr(fd, perf_ctl, buf);
//       writeln(buf[0],' ',buf[1],'  ',buf[2],' ',buf[3],'    ',buf[4],' ',buf[5],'  ',buf[6],' ',buf[7]);
buf[0]:=vid;
buf[1]:=fid;
wrmsr(fd, perf_ctl, buf);
end;


var fd,fid,vid,i : longint;
    s            : shortstring;
    msrfn        : ansistring;
    cpua,cpuz    : longint;

begin
for i:=1 to paramcount do
  if paramstr(i)='-h' then paramerr('');
if paramcount<1 then paramerr('');
  
s:=paramstr(1);
i:=2;
while (i<length(s)) and (s[i]<>'-') do
  i+=1;
if i<length(s) then 
    begin
    val3(copy(s,1,i-1),cpua);
    val3(copy(s,i+1,length(s)-i),cpuz);
    if cpuz<cpua then
      begin
      i:=cpuz;
      cpuz:=cpua;
      cpua:=i;
      end;
    end  
  else 
    begin
    val3(s,cpua);
    cpuz:=cpua;
    end;

if paramcount=1 then  
    begin
    for i:=cpua to cpuz do
      begin
      msrfn:='/dev/cpu/'+int2str(i)+'/msr';
      fd:=fdopen(msrfn,open_rdonly);
      if (fd<0) or (linuxerror<>0) then error('Error opening `'+msrfn+''': '+StrError(linuxerror));
      writeln('CPU',i);
      info(fd);
      writeln;
      fdclose(fd);
      end;
    end
  else if paramcount=2 then
    begin
    if paramstr(2)='-a' then
        begin
        for i:=cpua to cpuz do
   	  begin
          msrfn:='/dev/cpu/'+int2str(i)+'/msr';
          fd:=fdopen(msrfn,open_rdonly);
          if (fd<0) or (linuxerror<>0) then error('Error opening `'+msrfn+''': '+StrError(linuxerror));
          DSDTInfo(fd);
          fdclose(fd);
	  end;
        end
      else if paramstr(2)='-e' then
        begin
	for i:=cpua to cpuz do
          begin
          msrfn:='/dev/cpu/'+int2str(i)+'/msr';
          fd:=fdopen(msrfn,open_rdwr);
          if (fd<0) or (linuxerror<>0) then error('Error opening `'+msrfn+''': '+StrError(linuxerror));
	  enableEIST(fd,true);
          fdclose(fd);
          end;
	end
      else paramerr('`-a'' or `-e'' expected: `'+paramstr(2)+'''');
    end
  else if paramcount=3 then
    begin
    val3(paramstr(2),fid,255);
    val3(paramstr(3),vid,255);
    for i:=cpua to cpuz do
      begin
      msrfn:='/dev/cpu/'+int2str(i)+'/msr';
      fd:=fdopen(msrfn,open_rdwr);
      if (fd<0) or (linuxerror<>0) then error('Error opening `'+msrfn+''': '+StrError(linuxerror));
      setFidVid(fd, fid, vid);
      fdclose(fd);
      end;
    end
  else paramerr('Invalid command line');
end.

