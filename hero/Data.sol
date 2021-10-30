pragma ton-solidity >=0.43.0;

pragma AbiHeader expire;
pragma AbiHeader time;
//pragma AbiHeader pubkey;

import './resolvers/IndexResolver.sol';

import './interfaces/IData.sol';

import './libraries/Constants.sol';


contract Data is IData, IndexResolver {
    address _addrRoot;
    address public _addrOwner;
    address _addrStorage;
    address _beneficiary;

    uint256 static _id;

    Constants.Hero  hero;
    address _approvedAddr;


    event leveled(address  owner, uint level, uint summoner);

    constructor(address addrOwner,Constants.Hero _hero, TvmCell codeIndex ) public {
        require(msg.value >= Constants.MIN_FOR_DEPLOY,108);
        optional(TvmCell) optSalt = tvm.codeSalt(tvm.code());
        require(optSalt.hasValue(), 101);
        (address addrRoot) = optSalt.get().toSlice().decode(address);
        require(msg.sender == addrRoot);
        tvm.accept();
        _addrRoot = addrRoot;
        _addrOwner = addrOwner;
        _codeIndex = codeIndex;

        hero=_hero;
        hero.xp=0;
        hero.level=1;
        hero.adventurers_log=0;

        deployIndex(_addrOwner);
    }

        modifier isApprovedOrOwner{
            require(msg.sender == _addrOwner||msg.sender==_approvedAddr, Constants.err_owner_sender);
            tvm.accept();
            _;
        }

    function approve(address appr)public isApprovedOrOwner{
        require(msg.value >= Constants.MIN_FOR_DEPLOY, Constants.err_comm_gas);
        _approvedAddr=appr;
        _addrOwner.transfer(0,true,64);
    }

    function adventure() public isApprovedOrOwner  returns(bool success){
        require(msg.value >= Constants.MIN_FOR_DEPLOY, Constants.err_comm_gas);
        require(now > hero.adventurers_log,Constants.err_hero_log);
        hero.adventurers_log= now + Constants.DAY;
        hero.xp += Constants.xp_per_day;
        success=true;
        _addrOwner.transfer(0,true,64);
    }

    function spend_xp( uint xp) public isApprovedOrOwner{
        require(msg.sender == _addrOwner, Constants.err_owner_sender);
        require(msg.value >= Constants.MIN_FOR_DEPLOY, Constants.err_comm_gas);
        hero.xp -= xp;
        _addrOwner.transfer(0,true,64);
    }

    function level_up() public isApprovedOrOwner returns(bool success){
       // require(msg.sender == _addrOwner, Constants.err_owner_sender);
        uint _xp_required = xp_required(hero.level);
        if(hero.xp >= _xp_required){
            hero.xp -= _xp_required;
            hero.level = hero.level+1;
            emit leveled(msg.sender, hero.level, hero.id);
            success=true;
        }else{
            success=false;
        }
        _addrOwner.transfer(0,true,64);
    }
    function xp_required(uint curent_level) public pure returns (uint xp_to_next_level) {
        xp_to_next_level = curent_level * 1000;
        for (uint i = 1; i < curent_level; i++) {
            xp_to_next_level += i * 1000;
        }
    }
    function tokenURI( ) public view returns (string uri) {
        string  parts = '<svg xmlns="http://www.w3.org/2000/svg" preserveAspectRatio="xMinYMin meet" viewBox="0 0 350 350"><style>.base { fill: white; font-family: serif; font-size: 14px; }</style><rect width="100%" height="100%" fill="black" /><text x="10" y="20" class="base">';
        parts.append(format("No. {}",hero.id));

        parts.append('</text><text x="10" y="40" class="base">');
        parts.append(format("name: {}",hero.name));

        parts.append('</text><text x="10" y="60" class="base">');
        parts.append(format("race: {}",hero.race));

        parts.append('</text><text x="10" y="80" class="base">');
        parts.append(format("gender: {}",hero.gender));

        parts.append('</text><text x="10" y="100" class="base">');
        parts.append(format("imgNum: {}",hero.imgNum));

        parts.append('</text><text x="10" y="120" class="base">');
        parts.append(format("class: {}",hero.class));

        parts.append('</text><text x="10" y="140" class="base">');

        parts.append(format("level: {}",hero.level));

        parts.append('</text><text x="10" y="160" class="base">');

        parts.append(format("xp: {}",hero.xp));

        parts.append('</text></svg>');

        return parts;
    }


    function transferOwnership(address addrTo) isApprovedOrOwner public override {
        require(msg.value >= Constants.MIN_FOR_DEPLOY, Constants.err_comm_gas);

        address oldIndexOwner = resolveIndex(_addrRoot, address(this), _addrOwner);
        IIndex(oldIndexOwner).destruct();
        address oldIndexOwnerRoot = resolveIndex(address(0), address(this), _addrOwner);
        IIndex(oldIndexOwnerRoot).destruct();

        _addrOwner = addrTo;
        hero.ownerAddr=addrTo;

        deployIndex(addrTo);
    }

    function deployIndex(address owner) private {
        TvmCell codeIndexOwner = _buildIndexCode(_addrRoot, owner);
        TvmCell stateIndexOwner = _buildIndexState(codeIndexOwner, address(this));
        new Index{stateInit: stateIndexOwner, value: 0.1 ton}(_addrRoot);

        TvmCell codeIndexOwnerRoot = _buildIndexCode(address(0), owner);
        TvmCell stateIndexOwnerRoot = _buildIndexState(codeIndexOwnerRoot, address(this));
        new Index{stateInit: stateIndexOwnerRoot, value: 0.1 ton}(_addrRoot);
    }
    function getInfo() public view override returns (
        address addrRoot,
        address addrOwner,
        address addrData
    ) {
        addrRoot = _addrRoot;
        addrOwner = _addrOwner;
        addrData = address(this);
    }


    function getOwner() public view override returns(address addrOwner) {
        addrOwner = _addrOwner;
    }
    function getOwnerAndAppr() public responsible view returns(address addrOwner,address approver) {
        return{value: 0, flag: 64} (_addrOwner,_approvedAddr);
    }

    function summoner() public view responsible returns (Constants.Hero _hero,address approvedAddr) {
        return{value: 0, flag: 64} (hero,_approvedAddr);
    }
    fallback() external {
    }
}
