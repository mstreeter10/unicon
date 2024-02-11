BASE = ../../..
include $(BASE)/Makedefs.uni

UFLAGS=-s -u

SRC       = ../icode.icn ../srcfile.icn ../state.icn \
            ../agent.icn ../internals.icn ../externals.icn \
            ../breakpoint.icn ../watchpoint.icn ../stepping.icn ../stack.icn ../data.icn \
            ../trace.icn \
            ../evaluator.icn ../session.icn ../console.icn ../defaults.icn ../help.icn \
            ../coexp.icn ../symtab.icn ../system.icn launch-dap.icn server.icn \
            communicator.icn

OBJ = launch-dap.u server.u communicator.u

UFILES    = ../icode.u ../srcfile.u ../state.u \
            ../agent.u ../internals.u ../externals.u \
            ../breakpoint.u ../watchpoint.u ../stepping.u ../stack.u ../data.u \
            ../trace.u  \
            ../evaluator.u ../session.u ../console.u ../help.u ../coexp.u ../symtab.u ../system.u

LIB       = ../lib
LIBRARY   = $(LIB)/listener.u      $(LIB)/memory.u     $(LIB)/structaliases.u \
            $(LIB)/structusage.u   $(LIB)/looptime.u   $(LIB)/proctime.u \
            $(LIB)/procprofile.u   $(LIB)/varprofile.u $(LIB)/deadvar.u \
            $(LIB)/failedloop.u    $(LIB)/failedsubscript.u\
            $(LIB)/typechange.u \
            $(LIB)/counter_deref.u       $(LIB)/counter_pcall.u \
            $(LIB)/counter_line.u  $(LIB)/counter_syntax.u

DTA        = ../dta
DTA_UFILES = $(DTA)/atomic_agent.u $(DTA)/temporals.u

.PHONY:all

all: dapcom udap 

udap: $(OBJ)
	$(UC) $(DASHG) -o udap $(LIBRARY) $(DTA_UFILES) $(UFILES) $(OBJ)
	$(CP) udap$(EXE) ../../../bin

launch-dap.u:launch-dap.icn server.u
server.u:server.icn communicator.u
communicator.u:communicator.icn udb 

udb:
	cd ..; $(MAKE) udbonly

dapcom:dapcom.icn
	$(UC) $(DASHG) -o dapcom dapcom.icn
	$(CP) dapcom$(EXE) ../../../bin

zip:
	zip udap.zip Makefile *.icn

clean:
	$(RM) -f *.u $(prog)$(EXE) uniclass* dapcom$(EXE)