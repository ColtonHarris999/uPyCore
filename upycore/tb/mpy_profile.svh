// Simulation-only passive profiler. Included only by tb_mpy_soc with MPY_PROFILE.
// Count posedges in [first native _ticks sample, second sample), exactly
// matching the values returned by _ticks. No core/firmware signals are driven.
localparam int PR_WORDS=131072, PR_FUNCS=2048, PR_STATES=2048, PR_DEPTH=128;
integer pr_stateflags[PR_STATES];
integer pr_lut[PR_WORDS]; // bits 15:0 function, 23:16 semantic group, 24 firmware
integer pr_frame_fn[PR_WORDS], pr_frame_parent[PR_WORDS], pr_frame_group[PR_WORDS];
longint unsigned pr_self[PR_FUNCS],pr_incl[PR_FUNCS],pr_entries[PR_FUNCS];
longint unsigned pr_group[16],pr_reason[12],pr_cross[16][12],pr_state[PR_STATES];
longint unsigned pr_pc[524288];
longint unsigned pr_total=0,pr_last=0,pr_start=0,pr_stop=0;
longint unsigned pr_bload=0,pr_bstore=0,pr_commands=0,pr_queue=0,pr_allocs=0,pr_alloc_words=0,pr_collections=0;
integer pr_fd=0,pr_ticks=0,pr_pending=0,pr_last_fb=-1,pr_last_rc=-1,pr_last_fp=-1;
integer pr_path[PR_DEPTH],pr_npath=0,pr_group_now=0,pr_badpath=0;
bit pr_on=0,pr_tick_old=0,pr_done=0;
string pr_pathname,pr_lutname,pr_statesname;

task automatic pr_flush_path();
    for(integer k=0;k<pr_npath;k++) pr_incl[pr_path[k]]+=pr_total-pr_last;
    pr_last=pr_total;
endtask

task automatic pr_dump();
    if(pr_fd!=0 && !pr_done) begin
        pr_flush_path();
        $fwrite(pr_fd,"META %0d %0d %0d %0d %0d\n",pr_start,pr_stop,pr_total,pr_ticks,pr_badpath);
        for(integer k=0;k<PR_FUNCS;k++) if(pr_self[k]!=0 || pr_incl[k]!=0)
            $fwrite(pr_fd,"FUNCTION %0d %0d %0d %0d\n",k,pr_self[k],pr_incl[k],pr_entries[k]);
        for(integer k=0;k<16;k++) begin
            $fwrite(pr_fd,"GROUP %0d %0d\n",k,pr_group[k]);
            for(integer j=0;j<12;j++) if(pr_cross[k][j]!=0) $fwrite(pr_fd,"CROSS %0d %0d %0d\n",k,j,pr_cross[k][j]);
        end
        for(integer k=0;k<12;k++) $fwrite(pr_fd,"REASON %0d %0d\n",k,pr_reason[k]);
        for(integer k=0;k<PR_STATES;k++) if(pr_state[k]!=0) $fwrite(pr_fd,"STATE %0d %0d\n",k,pr_state[k]);
        for(integer k=0;k<524288;k++) if(pr_pc[k]!=0) $fwrite(pr_fd,"PC %0d %0d\n",k,pr_pc[k]);
        $fwrite(pr_fd,"EVENT bytearray_load_fallback %0d\nEVENT bytearray_store_fallback %0d\nEVENT copy_commands %0d\nEVENT copy_admission_wait %0d\nEVENT allocation_requests %0d\nEVENT allocated_words_requested %0d\nEVENT collection_requests %0d\n",pr_bload,pr_bstore,pr_commands,pr_queue,pr_allocs,pr_alloc_words,pr_collections);
        $fclose(pr_fd);pr_done=1;
    end
endtask

initial begin
    if($value$plusargs("PROFILE=%s",pr_pathname)) begin
        if(!$value$plusargs("PROFILE_LUT=%s",pr_lutname)) $fatal(1,"PROFILE_LUT required");
        $readmemh(pr_lutname,pr_lut);
        if(!$value$plusargs("PROFILE_STATES=%s",pr_statesname)) $fatal(1,"PROFILE_STATES required");
        $readmemh(pr_statesname,pr_stateflags);
        pr_fd=$fopen(pr_pathname,"w");
        if(pr_fd==0) $fatal(1,"Cannot open PROFILE output");
    end
end

always @(posedge clk) if(pr_fd!=0 && !pr_done && rst_n && boot_done) begin : profile_sample
    integer fid,entry,gid,reason,fb,fp,walk,fn,eff;
    bit tick,transition,changed;

    tick=u_soc.u_core.st==u_soc.u_core.S_NAT_A && u_soc.u_core.nid==8'd22;
    eff=u_soc.u_core.st==u_soc.u_core.S_MWAIT ? int'(u_soc.u_core.wret) : int'(u_soc.u_core.st);
    transition=(pr_stateflags[eff]&1)!=0;
    fb=((u_soc.u_core.fbase & 32'h1fffffff)>>2)+1;
    fp=u_soc.u_core.fprev==0 ? 0 : ((u_soc.u_core.fprev & 32'h1fffffff)>>2)+1;
    entry=(u_soc.u_core.rc>>2)<PR_WORDS ? pr_lut[u_soc.u_core.rc>>2] : 0;
    fid=entry&65535;
    if(fid>=PR_FUNCS) $fatal(1,"Function LUT overflow");
    changed=fb!=pr_last_fb || u_soc.u_core.rc!=pr_last_rc || fp!=pr_last_fp;
    // Cache frame ancestry only when frame restoration is coherent. During
    // restore the new fbase and old rc can coexist: charge those cycles to an
    // explicit transition bucket instead of inventing a callable owner.
    if(transition && pr_npath!=0) begin pr_flush_path();pr_npath=0;pr_last_fb=-1;end
    if(!transition && fid!=0 && fb<PR_WORDS && changed) begin
        pr_flush_path();
        gid=(entry>>16)&255;
        if((gid==12 || gid==13) && pr_frame_fn[fb]==fid && (pr_frame_group[fb]==2 || pr_frame_group[fb]==3))gid=pr_frame_group[fb];
        pr_frame_fn[fb]=fid;pr_frame_parent[fb]=fp;
        if(pr_pending!=0 && (gid==12 || gid==13)) begin gid=pr_pending;pr_pending=0;end
        if(gid==0 && fp!=0 && fp<PR_WORDS) gid=pr_frame_group[fp];
        pr_frame_group[fb]=gid;
        pr_npath=0;walk=fb;pr_group_now=gid;
        for(integer k=0;k<PR_DEPTH && walk!=0;k++) begin
            if(walk>=PR_WORDS || pr_frame_fn[walk]==0) begin pr_badpath++;break;end
            fn=pr_frame_fn[walk];
            // Recursive frames count once per function, not once per depth.
            begin : unique_fn
                bit seen;seen=0;
                for(integer j=0;j<pr_npath;j++) if(pr_path[j]==fn)seen=1;
                if(!seen) begin pr_path[pr_npath]=fn;pr_npath++;end
            end
            if(pr_frame_parent[walk]==walk) begin pr_badpath++;break;end
            walk=pr_frame_parent[walk];
        end
        if(walk!=0) pr_badpath++;
        pr_last_fb=fb;pr_last_rc=u_soc.u_core.rc;pr_last_fp=fp;
    end
    if(tick && !pr_tick_old) begin
        pr_ticks++;
        if(pr_ticks==1) begin pr_start=cycles;pr_on=1;pr_last=0;end
        else if(pr_ticks==2) begin pr_stop=cycles;pr_on=0;pr_dump();end
    end
    pr_tick_old=tick;
    if(u_soc.u_core.st==u_soc.u_core.S_CF_SW && (((u_soc.u_core.x3 & 32'h1fffffff)>>2)+1)<PR_WORDS)
        pr_frame_fn[((u_soc.u_core.x3 & 32'h1fffffff)>>2)+1]=0;
    if(pr_on) begin
        if(transition) begin gid=11;fid=0;end
        else begin gid=pr_group_now;if(gid==0)gid=entry[24] ? 1 : 0;end
        reason=0;
        if(u_soc.u_core.st==u_soc.u_core.S_AL_W) reason=1;
        else if((pr_stateflags[eff]&2)!=0) reason=2;
        else if(u_soc.u_core.st==u_soc.u_core.S_MWAIT && !u_soc.c_ack) begin
            if(u_soc.ca_busy && !u_soc.c_sim)reason=3;
            else if(u_soc.c_want && !u_soc.m_gnt[1] && !u_soc.c_sim)reason=4;
            else reason=5;
        end else if(u_soc.u_core.st==u_soc.u_core.S_FETCH && u_soc.u_core.fe_avail==0) reason=6;
        else if((pr_stateflags[eff]&4)!=0)reason=7;
        else if((pr_stateflags[eff]&8)!=0 || transition)reason=8;
        else if((pr_stateflags[eff]&16)!=0)reason=9;
        pr_total++;pr_self[fid]++;pr_group[gid]++;pr_reason[reason]++;pr_cross[gid][reason]++;pr_state[int'(u_soc.u_core.st)]++;
        if(trace && trace_pc<524288)pr_pc[trace_pc]++;
        if(u_soc.u_core.st==u_soc.u_core.S_LS_FB && u_soc.u_core.t[0][35:32]==10 && u_soc.u_core.t[0][1:0]==3)begin pr_bload++;pr_pending=2;end
        if(u_soc.u_core.st==u_soc.u_core.S_SS_FB && u_soc.u_core.t[0][35:32]==10 && u_soc.u_core.t[0][1:0]==3)begin pr_bstore++;pr_pending=3;end
        if(u_soc.u_core.st==u_soc.u_core.S_CF_SW)pr_entries[(pr_lut[u_soc.u_core.c_rc>>2]&65535)]++;
        if(u_soc.ca_valid && u_soc.ca_ready)pr_commands++;
        if(u_soc.u_core.st==u_soc.u_core.S_NAT_WCA && !u_soc.u_core.ca_ok)pr_queue++;
        if(u_soc.u_core.gc_alloc_req)begin pr_allocs++;pr_alloc_words+=u_soc.u_core.al_n;end
        if(u_soc.u_core.gc_collect_req)pr_collections++;
    end
end
final begin
    if(pr_fd!=0 && !pr_done) begin pr_stop=cycles;pr_dump();end
end
