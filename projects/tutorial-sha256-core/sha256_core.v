// SHA-256 single-block compression core (iterative, one round/cycle).
// Host provides one already-padded 512-bit message block; core outputs the
// 256-bit digest. Verified against the FIPS-180-4 known-answer test for "abc".
module sha256_core (
  input  wire          clk,
  input  wire          rst,        // synchronous, active high
  input  wire          start,      // pulse to begin on `block`
  input  wire [511:0]  block,      // padded 512-bit message block
  output reg  [255:0]  hash,       // digest (valid when done=1)
  output reg           done
);
  function [31:0] ror; input [31:0] x; input [4:0] n; begin ror = (x >> n) | (x << (32-n)); end endfunction
  function [31:0] s0;  input [31:0] x; begin s0 = ror(x,7)  ^ ror(x,18) ^ (x>>3);  end endfunction
  function [31:0] s1;  input [31:0] x; begin s1 = ror(x,17) ^ ror(x,19) ^ (x>>10); end endfunction
  function [31:0] S0;  input [31:0] x; begin S0 = ror(x,2)  ^ ror(x,13) ^ ror(x,22); end endfunction
  function [31:0] S1;  input [31:0] x; begin S1 = ror(x,6)  ^ ror(x,11) ^ ror(x,25); end endfunction
  function [31:0] ch;  input [31:0] e,f,g; begin ch = (e&f) ^ (~e&g); end endfunction
  function [31:0] maj; input [31:0] a,b,c; begin maj = (a&b)^(a&c)^(b&c); end endfunction
  function [31:0] kc;  input [6:0] t; begin
    case (t)
      0:kc=32'h428a2f98;1:kc=32'h71374491;2:kc=32'hb5c0fbcf;3:kc=32'he9b5dba5;
      4:kc=32'h3956c25b;5:kc=32'h59f111f1;6:kc=32'h923f82a4;7:kc=32'hab1c5ed5;
      8:kc=32'hd807aa98;9:kc=32'h12835b01;10:kc=32'h243185be;11:kc=32'h550c7dc3;
      12:kc=32'h72be5d74;13:kc=32'h80deb1fe;14:kc=32'h9bdc06a7;15:kc=32'hc19bf174;
      16:kc=32'he49b69c1;17:kc=32'hefbe4786;18:kc=32'h0fc19dc6;19:kc=32'h240ca1cc;
      20:kc=32'h2de92c6f;21:kc=32'h4a7484aa;22:kc=32'h5cb0a9dc;23:kc=32'h76f988da;
      24:kc=32'h983e5152;25:kc=32'ha831c66d;26:kc=32'hb00327c8;27:kc=32'hbf597fc7;
      28:kc=32'hc6e00bf3;29:kc=32'hd5a79147;30:kc=32'h06ca6351;31:kc=32'h14292967;
      32:kc=32'h27b70a85;33:kc=32'h2e1b2138;34:kc=32'h4d2c6dfc;35:kc=32'h53380d13;
      36:kc=32'h650a7354;37:kc=32'h766a0abb;38:kc=32'h81c2c92e;39:kc=32'h92722c85;
      40:kc=32'ha2bfe8a1;41:kc=32'ha81a664b;42:kc=32'hc24b8b70;43:kc=32'hc76c51a3;
      44:kc=32'hd192e819;45:kc=32'hd6990624;46:kc=32'hf40e3585;47:kc=32'h106aa070;
      48:kc=32'h19a4c116;49:kc=32'h1e376c08;50:kc=32'h2748774c;51:kc=32'h34b0bcb5;
      52:kc=32'h391c0cb3;53:kc=32'h4ed8aa4a;54:kc=32'h5b9cca4f;55:kc=32'h682e6ff3;
      56:kc=32'h748f82ee;57:kc=32'h78a5636f;58:kc=32'h84c87814;59:kc=32'h8cc70208;
      60:kc=32'h90befffa;61:kc=32'ha4506ceb;62:kc=32'hbef9a3f7;63:kc=32'hc67178f2;
      default:kc=32'h0;
    endcase end
  endfunction

  localparam [31:0] H0=32'h6a09e667,H1=32'hbb67ae85,H2=32'h3c6ef372,H3=32'ha54ff53a,
                    H4=32'h510e527f,H5=32'h9b05688c,H6=32'h1f83d9ab,H7=32'h5be0cd19;

  reg [31:0] a,b,c,d,e,f,g,h;
  reg [31:0] w0,w1,w2,w3,w4,w5,w6,w7,w8,w9,w10,w11,w12,w13,w14,w15;
  reg [6:0]  t;
  reg        busy;

  wire [31:0] wt = w0;
  wire [31:0] t1 = h + S1(e) + ch(e,f,g) + kc(t) + wt;
  wire [31:0] t2 = S0(a) + maj(a,b,c);
  wire [31:0] wnew = s1(w14) + w9 + s0(w1) + w0;

  always @(posedge clk) begin
    if (rst) begin busy<=0; done<=0; t<=0; end
    else if (start && !busy) begin
      busy<=1; done<=0; t<=0;
      a<=H0;b<=H1;c<=H2;d<=H3;e<=H4;f<=H5;g<=H6;h<=H7;
      w0<=block[511:480];w1<=block[479:448];w2<=block[447:416];w3<=block[415:384];
      w4<=block[383:352];w5<=block[351:320];w6<=block[319:288];w7<=block[287:256];
      w8<=block[255:224];w9<=block[223:192];w10<=block[191:160];w11<=block[159:128];
      w12<=block[127:96];w13<=block[95:64];w14<=block[63:32];w15<=block[31:0];
    end else if (busy) begin
      // compression round
      h<=g;g<=f;f<=e;e<=d+t1;d<=c;c<=b;b<=a;a<=t1+t2;
      // slide message schedule
      w0<=w1;w1<=w2;w2<=w3;w3<=w4;w4<=w5;w5<=w6;w6<=w7;w7<=w8;
      w8<=w9;w9<=w10;w10<=w11;w11<=w12;w12<=w13;w13<=w14;w14<=w15;w15<=wnew;
      if (t==63) begin
        busy<=0; done<=1;
        hash<={H0+(t1+t2), H1+a, H2+b, H3+c, H4+(d+t1), H5+e, H6+f, H7+g};
      end else t<=t+1;
    end else done<=0;
  end
endmodule
