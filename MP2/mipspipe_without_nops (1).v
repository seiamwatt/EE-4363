module mipspipe(clock);
   input clock;

   parameter LW = 6'b100011, SW = 6'b101011, BEQ = 6'b000100, nop = 32'b00000_100000, ALUop = 6'b0; 
   reg [31:0] PC,
		  Regs[0:31],
			  IMemory[0:1023], DMemory[0:1023],
              IFIDIR, IDEXA, IDEXB, IDEXIR, EXMEMIR, EXMEMB,
              EXMEMALUOut, MEMWBValue, MEMWBIR;

   wire [4:0] IDEXrs, IDEXrt, EXMEMrd, MEMWBrd, MEMWBrt;
   wire [5:0] EXMEMop, MEMWBop, IDEXop;
   wire [31:0] Ain, Bin;

   assign IDEXrs = IDEXIR[25:21];
   assign IDEXrt = IDEXIR[20:16];
   assign EXMEMrd = EXMEMIR[15:11];
   assign MEMWBrd = MEMWBIR[15:11];
   assign MEMWBrt = MEMWBIR[20:16];
   assign EXMEMop = EXMEMIR[31:26];
   assign MEMWBop = MEMWBIR[31:26];
   assign IDEXop = IDEXIR[31:26];

   assign Ain = IDEXA;
   assign Bin = IDEXB;
   reg [5:0] i;
   reg [10:0] j,k;

   initial begin
      PC = 0;
      IFIDIR = nop; 
      IDEXIR = nop; 
      EXMEMIR = nop; 
      MEMWBIR = nop;
      for (i=0;i<=31;i=i+1) Regs[i] = i;
      
      IMemory[0] = 32'h00412820;
      IMemory[1] = 32'h8ca30004;
      IMemory[2] = 32'h8c420000;
      IMemory[3] = 32'h00a31825;
      IMemory[4] = 32'haca30000;
      for (j=5;j<=1023;j=j+1) IMemory[j] = nop;
      
      DMemory[0] = 32'hfffffff0;
      DMemory[1] = 32'hffffffff;
      for (k=2;k<=1023;k=k+1) DMemory[k] = 0;
   end
   
   always @ (posedge clock) 
   begin
      IFIDIR <= IMemory[PC>>2];
	  PC <= PC + 4;
    
      IDEXA <= Regs[IFIDIR[25:21]]; 
      IDEXB <= Regs[IFIDIR[20:16]];
      
	  IDEXIR <= IFIDIR;
      
      if ((IDEXop==LW) |(IDEXop==SW))
         EXMEMALUOut <= IDEXA +{{16{IDEXIR[15]}}, IDEXIR[15:0]};
      else if (IDEXop==ALUop) begin
         case (IDEXIR[5:0])
           32: EXMEMALUOut <= Ain + Bin;
           37: EXMEMALUOut <= Ain | Bin;
           default: ;
         endcase
      end
   
      EXMEMIR <= IDEXIR; EXMEMB <= IDEXB;
   
      if (EXMEMop==ALUop) MEMWBValue <= EXMEMALUOut;
      else if (EXMEMop == LW) MEMWBValue <= DMemory[EXMEMALUOut>>2];
      else if (EXMEMop == SW) DMemory[EXMEMALUOut>>2] <=EXMEMB;
   
      MEMWBIR <= EXMEMIR;
   
      if ((MEMWBop==ALUop) & (MEMWBrd != 0))
		Regs[MEMWBrd] <= MEMWBValue;
      else if ((MEMWBop == LW)& (MEMWBrt != 0))
		Regs[MEMWBrt] <= MEMWBValue;
    end

endmodule
