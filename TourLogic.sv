module TourLogic(clk,rst_n,x_start,y_start,go,done,indx,move);

  input clk,rst_n;				// 50MHz clock and active low asynch reset
  input [2:0] x_start, y_start;	// starting position on 5x5 board
  input go;						// initiate calculation of solution
  input [4:0] indx;				// used to specify index of move to read out
  output logic done;			// pulses high for 1 clock when solution complete
  output [7:0] move;			// the move addressed by indx (1 of 24 moves)
  
  ////////////////////////////////////////
  // Declare needed internal registers //
  //////////////////////////////////////
  
  //<< some internal registers to consider: >>
  //<< These match the variables used in knightsTourSM.pl >>
  reg [4:0] board[0:4][0:4];				// keeps track if position visited
  reg [7:0] last_move[0:23];		// last move tried from this spot
  reg [7:0] poss_moves[0:23];		// stores possible moves from this position as 8-bit one hot
  reg [7:0] move_try;				// one hot encoding of move we will try next
  reg [4:0] move_num;				// keeps track of move we are on
  reg [2:0] xx,yy;					// current x & y position  
 
  //<< 2-D array of 5-bit vectors that keep track of where on the board the knight
  //   has visited.  Will be reduced to 1-bit boolean after debug phase >>
  //<< 1-D array (of size 24) to keep track of last move taken from each move index >>
  //<< 1-D array (of size 24) to keep track of possible moves from each move index >>
  //<< move_try ... not sure you need this.  I had this to hold move I would try next >>
  //<< move number...when you have moved 24 times you are done.  Decrement when backing up >>
  //<< xx, yy couple of 3-bit vectors that represent the current x/y coordinates of the knight>>
  logic zero;
  logic init;
  logic update_position;
  logic backup;
  logic calculate_possibilites;
  logic do_new_move;
  logic [2:0] nxt_xx, nxt_yy, prev_xx, prev_yy;
  
  //<< below I am giving you an implementation of the one of the register structures you have >>
  //<< to infer (board[][]).  You need to implement the rest, and the controlling SM >>
  ///////////////////////////////////////////////////
  // The board memory structure keeps track of where 
  // the knight has already visited.  Initially this 
  // should be a 5x5 array of 5-bit numbers to store
  // the move number (helpful for debug).  Later it 
  // can be reduced to a single bit (visited or not)
  ////////////////////////////////////////////////	  
  always_ff @(posedge clk)
    if (zero)
	  board <= '{'{0,0,0,0,0},'{0,0,0,0,0},'{0,0,0,0,0},'{0,0,0,0,0},'{0,0,0,0,0}};
	else if (init)
	  board[x_start][y_start] <= 5'h1;	// mark starting position
	else if (update_position)
	  board[nxt_xx][nxt_yy] <= move_num + 2;	// mark as visited
	else if (backup)
	  board[xx][yy] <= 5'h0;			// mark as unvisited
  
  
  //<< Your magic occurs here >>
  // Output signal
  assign move = last_move[indx];
  
  // Last Move Flop
  always_ff @(posedge clk) begin
	if (zero) begin
		integer i;
		for (i = 0; i < 24; i++)
			last_move[i] <= 8'h00;
	end
	else if (update_position) begin
		last_move[move_num] <= move_try; // <= ?
	end
  end
  
  // Possible Moves Flop
  always_ff @(posedge clk) begin
	if (zero) begin
		integer i;
		for (i = 0; i < 24; i++)
			poss_moves[i][7:0] <= 8'h00;
	end
	else if (calculate_possibilites) begin
		poss_moves[move_num][7:0] <= calc_poss(xx, yy);
	end
  end
  
  // Current Move Number Flop
  always_ff @(posedge clk) begin
	if (zero) begin
		move_num <= 5'b00000;
	end
	else if (update_position) begin
		move_num <= move_num + 1;
	end
	else if (backup) begin
		move_num <= move_num - 1;
	end
  end
  
  // Previous and Next Position logic
  assign nxt_xx = xx + off_x(move_try);
  assign nxt_yy = yy + off_y(move_try);
  assign prev_xx = xx - off_x(last_move[move_num - 5'h01]);
  assign prev_yy = yy - off_y(last_move[move_num - 5'h01]);
  
  // Position Flop
  always_ff @(posedge clk) begin
	if (zero) begin
		xx <= 3'b000;
		yy <= 3'b000;
	end
	else if (init) begin
		xx <= x_start;
		yy <= y_start;
	end
	else if (update_position) begin
		xx <= nxt_xx;
		yy <= nxt_yy;
	end
	else if (backup) begin
		xx <= prev_xx;
		yy <= prev_yy;
	end
  end
  
  // Move try Flop
  always_ff @(posedge clk) begin
	if (zero) begin
		move_try <= 8'h00;
	end
	else if (init | calculate_possibilites) begin
		move_try <= 8'h01;
	end
	else if (do_new_move) begin
		move_try[7:0] <= move_try[7:0] << 1;
	end
	else if (backup) begin
		move_try <= (last_move[move_num - 1] << 1);   // <= ?
	end
  end
	
  // State Machine States
  typedef enum logic [2:0] {IDLE, INIT, POSSIBLE, MAKE_MOVE, BACKUP} state_t;
  
  state_t state, nxt_state;
  
  always_ff @(posedge clk, negedge rst_n) begin
	if (!rst_n)
		state <= IDLE;
	else
		state <= nxt_state;
  end
  
  always_comb begin
	init = 0;
	backup = 0;
	zero = 0;
	update_position = 0;
	calculate_possibilites = 0;
	do_new_move = 0;
	done = 0;
	nxt_state = state;
	
	case (state)
		IDLE: if (go) begin
			zero = 1;
			nxt_state = INIT;
		end
		
		INIT: begin
			init = 1;
			nxt_state = POSSIBLE;
		end
		
		POSSIBLE: begin
			calculate_possibilites = 1;
			nxt_state = MAKE_MOVE;
		end
		
		MAKE_MOVE: begin
			if ((poss_moves[move_num] & move_try[7:0]) && (board[nxt_xx][nxt_yy] == 5'h00)) begin
				update_position = 1;
				if (move_num[4:0] == 5'd23) begin
					nxt_state = IDLE;
					done = 1;
				end
			else
				nxt_state = POSSIBLE;
			end
			else if (move_try != 8'h80)
				do_new_move = 1;
			else
				nxt_state = BACKUP;
		end
		
		BACKUP: begin
			backup = 1;
			if (last_move[move_num - 1] != 8'h80)
				nxt_state = MAKE_MOVE;
		end
		
		default: nxt_state = IDLE;
	endcase
  end
  
  function [7:0] calc_poss(input [2:0] xpos,ypos);
    ///////////////////////////////////////////////////
	// Consider writing a function that returns a packed byte of
	// all the possible moves (at least in bound) moves given
	// coordinates of Knight.
	/////////////////////////////////////////////////////
	//logic [7:0] result;
	//result = 8'h00;
	//if (xpos < 3'h4 && ypos < 3'h3) result[0] = 1;
	//if (xpos > 3'h1 && ypos < 3'h3) result[1] = 1;
	//if (xpos > 3'h1 && ypos < 3'h4) result[2] = 1;
	//if (xpos > 3'h1 && ypos > 3'h0) result[3] = 1;
	//if (xpos > 3'h0 && ypos > 3'h1) result[4] = 1;
	//if (xpos < 3'h4 && ypos > 3'h1) result[5] = 1;
	//if (xpos < 3'h3 && ypos > 3'h0) result[6] = 1;
	//if (xpos < 3'h3 && ypos < 3'h4) result[7] = 1;
	//return result;
	logic [7:0] move1, move2, move3, move4, move5, move6, move7, move8;
	
	move1 = ((xpos < 3'h4) & (ypos < 3'h3)) ? 8'h01 : 8'h00;
	move2 = ((xpos > 3'h0) & (ypos < 3'h3)) ? 8'h02 : 8'h00;
	move3 = ((xpos > 3'h1) & (ypos < 3'h4)) ? 8'h04 : 8'h00;
	move4 = ((xpos > 3'h1) & (ypos > 3'h0)) ? 8'h08 : 8'h00;
	move5 = ((xpos > 3'h0) & (ypos > 3'h1)) ? 8'h10 : 8'h00;
	move6 = ((xpos < 3'h4) & (ypos > 3'h1)) ? 8'h20 : 8'h00;
	move7 = ((xpos < 3'h3) & (ypos > 3'h0)) ? 8'h40 : 8'h00;
	move8 = ((xpos < 3'h3) & (ypos < 3'h4)) ? 8'h80 : 8'h00;
	calc_poss = move1 | move2 | move3 | move4 | move5 | move6 | move7 | move8;
	return calc_poss;
  endfunction
  
  function signed [2:0] off_x(input [7:0] try);
    ///////////////////////////////////////////////////
	// Consider writing a function that returns a the x-offset
	// the Knight will move given the encoding of the move you
	// are going to try.  Can also be useful when backing up
	// by passing in last move you did try, and subtracting 
	// the resulting offset from xx
	/////////////////////////////////////////////////////
	if ((try == 8'h01) | (try == 8'h20))
		off_x = 3'h1;
	else if ((try == 8'h02) | (try == 8'h10))
		off_x = -3'h1;
	else if ((try == 8'h40) | (try == 8'h80))
		off_x = 3'h2;
	else if ((try == 8'h04) | (try == 8'h08))
		off_x = -3'h2;
	return off_x;
  endfunction
  
  function signed [2:0] off_y(input [7:0] try);
    ///////////////////////////////////////////////////
	// Consider writing a function that returns a the y-offset
	// the Knight will move given the encoding of the move you
	// are going to try.  Can also be useful when backing up
	// by passing in last move you did try, and subtracting 
	// the resulting offset from yy
	/////////////////////////////////////////////////////
	if ((try == 8'h04) | (try == 8'h80))
		off_y = 3'h1;
	else if ((try == 8'h08) | (try == 8'h40))
		off_y = -3'h1;
	else if ((try == 8'h01) | (try == 8'h02))
		off_y = 3'h2;
	else if ((try == 8'h10) | (try == 8'h20))
		off_y = -3'h2;
	return off_y;
  endfunction
  
endmodule
	  
      
  