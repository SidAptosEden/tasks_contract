module edenx::edenx_task {
    use aptos_std::table::Table;
    use aptos_framework::account::SignerCapability;
    use aptos_framework::resource_account;
    use aptos_std::table;
    use std::signer;
    use std::error;

    const ENOT_AUTHORIZED: u64 = 100001;
    const TASK_ID_ALREADY_EXISTS: u64 = 100002;
    const INVALID_ARGUMENT: u64 = 100003;
    const NOLOGIN_ACCOUNT: u64 = 100004;
    const TASKS_IS_END: u64 = 100005;
    const TASKS_IS_END_ALL: u64 = 100006;
    struct Task has store, drop, copy {
        task_id: u64,
        task_code: u64,
        task_points: u8,
        on_off: u8,
        total_participants: u64,
        task_type: u8,
        task_count: u8,
        basics_award: u8
    }

    struct Member has store, key {
        member_addr: address,
        total_task_points: u64,
        tasks: Table<u64, MemberTasksList>
    }

    struct MemberTasksList has store, drop, copy {
        task_id: u64,
        is_completed: u8
    }

    struct TaskList has store, key {
        tasks: Table<u64, Task>
    }

    struct ModuleData has key {
        // Storing the signer capability here, so the module can programmatically sign for transactions
        signer_cap: SignerCapability,
    }

    fun init_module(resource_signer: &signer) {
        let resource_signer_cap = resource_account::retrieve_resource_account_cap(resource_signer,@eden_tasks);

        move_to(resource_signer, TaskList{ tasks: table::new() });

        move_to(resource_signer, ModuleData { signer_cap: resource_signer_cap });
    }

    public entry fun create_task(
        _signer: &signer,
        _task_id: u64,
        _task_points: u8,
        _task_type: u8,
        _task_code: u64,
        _task_count: u8,
        _basics_award: u8
    )  acquires TaskList  {
        let publisher = signer::address_of(_signer);

        assert!(publisher == @admin_addr, error::permission_denied(ENOT_AUTHORIZED));

        let task_list = borrow_global_mut<TaskList>(@edenx);

        assert!(!table::contains(&task_list.tasks, _task_id), error::already_exists(TASK_ID_ALREADY_EXISTS));

        let task = Task{
            task_id: _task_id,
            task_code: _task_code,
            task_points: _task_points,
            on_off: 0,
            total_participants: 0,
            task_type: _task_type,
            task_count: _task_count,
            basics_award: _basics_award
        };

        table::upsert(&mut task_list.tasks, _task_id, task);
    }

    public entry fun start_tasks(_signer: &signer, _task_id: u64) acquires TaskList, Member {
        let task_list = borrow_global_mut<TaskList>(@edenx);

        if (!table::contains(&task_list.tasks, _task_id)) abort INVALID_ARGUMENT;

        let tasks = table::borrow(&mut task_list.tasks, _task_id);

        let addrress = signer::address_of(_signer);

        if (!exists<Member>(addrress)) {
            move_to(_signer, Member{
                member_addr: addrress,
                total_task_points: 0,
                tasks: table::new()
            });
        };

        let member = borrow_global_mut<Member>(addrress);

        if (table::contains(&member.tasks, _task_id)) {
            let member_tasks_list= table::borrow_mut(&mut member.tasks, _task_id);
            assert!(member_tasks_list.is_completed == 0, error::invalid_argument(INVALID_ARGUMENT));

            member_tasks_list.is_completed = 1;
        } else {
            let member_task = MemberTasksList {
                task_id: _task_id,
                is_completed: 1
            };

            table::upsert(&mut member.tasks, _task_id, member_task);
        };

        member.total_task_points = member.total_task_points + ((tasks.basics_award) as u64);

    }

    public entry fun end_tasks(_signer: &signer, _task_id: u64, _task_code: u64, _correct: u8)  acquires TaskList, Member  {
        let member_address = signer::address_of(_signer);

        assert!(exists<Member>(member_address), error::permission_denied(NOLOGIN_ACCOUNT));

        let member = borrow_global_mut<Member>(member_address);

        assert!(member.member_addr == member_address, error::permission_denied(NOLOGIN_ACCOUNT));
        //
        if (!table::contains(&member.tasks, _task_id)) abort 11;

        let member_tasks = table::borrow_mut(&mut member.tasks, _task_id);

        assert!(member_tasks.is_completed == 1, error::invalid_argument(INVALID_ARGUMENT));

        let task_list = borrow_global_mut<TaskList>(@edenx);

        if (!table::contains(&task_list.tasks, _task_id)) abort 22;

        let tasks = table::borrow_mut(&mut task_list.tasks, _task_id);

        assert!(tasks.on_off == 0, error::invalid_state(TASKS_IS_END));

        if (tasks.task_code != _task_code) abort 33;

        if (_correct > tasks.task_count) abort 44;

        member.total_task_points = member.total_task_points + ((tasks.task_points * _correct) as u64);
        member_tasks.is_completed = 2;

        tasks.total_participants = tasks.total_participants + 1;
    }

    public entry fun set_tasks_info(
        _signer: &signer,
        _task_id: u64,
        _task_points: u8,
        _task_type: u8,
        _task_code: u64,
        _task_count: u8,
        _basics_award: u8
    ) acquires TaskList {
        let publisher = signer::address_of(_signer);

        assert!(publisher == @admin_addr, error::permission_denied(ENOT_AUTHORIZED));

        let task_list = borrow_global_mut<TaskList>(@edenx);

        assert!(table::contains(&task_list.tasks, _task_id), error::already_exists(TASK_ID_ALREADY_EXISTS));

        let task_info = table::borrow_mut(&mut task_list.tasks, _task_id);
        task_info.task_points = _task_points;
        task_info.task_type = _task_type;
        task_info.task_count = _task_count;
        task_info.basics_award = _basics_award;
    }

    #[view]
    public  fun get_tasks_info(_task_id: u64): (u8, u8, u64, u8)  acquires TaskList {
        // assert signer has created a list
        // assert!(exists<TaskList>(@eden_tasks), error::invalid_argument(INVALID_ARGUMENT));
        // gets the TaskList resource
        let task_list = borrow_global<TaskList>(@edenx);
        let tasks = table::borrow(&task_list.tasks, _task_id);
        (tasks.task_points, tasks.task_type, tasks.task_code, tasks.task_count)
    }

    #[view]
    public fun get_counter(_task_id: u64) :u8 acquires TaskList {
        // assert signer has created a list
        // assert!(exists<TaskList>(@eden_tasks), error::invalid_argument(INVALID_ARGUMENT));
        // gets the TaskList resource
        let task_list = borrow_global<TaskList>(@edenx);
        let tasks = table::borrow(&task_list.tasks, _task_id);
        tasks.task_points
    }

    #[view]
    public fun get_member_task_state(_member_addr: address, _task_id: u64):u8 acquires Member {
        let is_completed = 0;

        if (exists<Member>(_member_addr)) {
            let member = borrow_global<Member>(_member_addr);
            if (table::contains(&member.tasks, _task_id)) {
                is_completed = table::borrow(&member.tasks, _task_id).is_completed;
            };
        };

        is_completed
    }

    #[view]
    public fun get_member_points(_member_addr: address):u64 acquires Member {
        let points = 0;
        if (exists<Member>(_member_addr)) {
            points = borrow_global<Member>(_member_addr).total_task_points;
        };

        points
    }
}
