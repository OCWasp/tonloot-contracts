pragma ton-solidity >= 0.43.0;
pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

import "../../components/debots/Interfaces/Debot.sol";
import "../../components/debots/Interfaces/Terminal.sol";
import "../../components/debots/Interfaces/Menu.sol";
import "../../components/debots/Interfaces/Msg.sol";
import "../../components/debots/Interfaces/ConfirmInput.sol";
import "../../components/debots/Interfaces/AddressInput.sol";
import "../../components/debots/Interfaces/NumberInput.sol";
import "../../components/debots/Interfaces/AmountInput.sol";
import "../../components/debots/Interfaces/Sdk.sol";
import "../../components/debots/Interfaces/Upgradable.sol";
import "../../components/debots/Interfaces/SigningBoxInput.sol";
import "../../components/debots/Interfaces/Media.sol";

import "./NftRoot.sol";
import "./IndexBasis.sol";
import "./Data.sol";
import "./Index.sol";
import "./HeroAttributes/HeroAttributes.sol";

interface IMultisig {
    function submitTransaction(
        address dest,
        uint128 value,
        bool bounce,
        bool allBalance,
        TvmCell payload)
    external returns (uint64 transId);

    function sendTransaction(
        address dest,
        uint128 value,
        bool bounce,
        uint8 flags,
        TvmCell payload)
    external;
}

contract NftDebot is Debot, Upgradable {

    TvmCell _codeNFTRoot;
    TvmCell _codeBasis;
    TvmCell _codeData;
    TvmCell _codeIndex;
    bytes[] intoLogo;
    bytes _icon;

    address _addrNFTRoot;
    uint256 _totalMinted;

    address _addrMultisig;
    uint128 currMintPrice;

    uint32 _keyHandle;
    string[] _allClasses;
    string[] _allRace;
    uint256 _tokenId;
    address _tokenDataAddr;
    address _transToAddr;
    optional(uint256) _pubkey;

    Constants.Hero[] _owners;
    Constants.Hero _tempHero;

    address _attributeAddr;


    uint8 _race;
    uint8 _gender;
    uint8 _class;

    modifier accept {
        require(msg.pubkey() == tvm.pubkey(), 102);
        tvm.accept();
        _;
    }

    constructor (address addrNFTRoot,address attributeAddr) public {
        tvm.accept();
        _addrNFTRoot=addrNFTRoot;
        _attributeAddr=attributeAddr;
    }
    function setAddrNftRoot(address addrNFTRoot)public accept{
        _addrNFTRoot=addrNFTRoot;
    }
    function setAttributeAddr(address attributeAddr)public accept{
        _attributeAddr=attributeAddr;
    }

    /*
    * Uploaders
    */

    function setNftRootCode(TvmCell code) public accept {
        _codeNFTRoot = code;
    }
    function setBasisCode(TvmCell code) public accept {
        _codeBasis = code;
    }
    function setDataCode(TvmCell code) public accept {
        _codeData = code;
    }
    function setIndexCode(TvmCell code) public accept {
        _codeIndex = code;
    }
    function setIcon(bytes icon)public accept{
        _icon=icon;
    }
    function initLogo(uint8 index,bytes punk)public accept{
        intoLogo.push(punk);
    }

    /*
     *  Overrided Debot functions
     */

    /// @notice Returns Metadata about DeBot.
    function getDebotInfo() public functionID(0xDEB) override view returns(
        string name, string version, string publisher, string key, string author,
        address support, string hello, string language, string dabi, bytes icon
    ) {
        name = "HERO test metaverse";
        version = "VB0.0.1";
        publisher = "";
        key = "";
        author = "0:e04f624c56471eae61806fef11790a73c7e61893f8bc47f60ff2b0033719a30f";
        support = _addrNFTRoot;
        hello = "You need to recruit heroes to explore, compete and conquer on this metaverse land.There are many heroes wondering and waiting to be summoned. But bear in mind that, some of them are not quite talented. Therefore be wise to select the most suitable hero for your adventure.";
        language = "en";
        dabi = m_debotAbi.get();
        icon = _icon;
    }

    function getRequiredInterfaces() public view override returns (uint256[] interfaces) {
        return [ Terminal.ID, Menu.ID, AddressInput.ID, SigningBoxInput.ID, ConfirmInput.ID, AmountInput.ID,NumberInput.ID ,Media.ID];
    }

    function start() public override {
        if(intoLogo.length>0){
            bytes logoImg="";
            for(bytes part:intoLogo){
            logoImg.append(part);
            }
            Media.output(tvm.functionId(mainMenu), "", logoImg);
        }else{
            mainMenu(MediaStatus.Success);
        }
    }

    function mainMenu(MediaStatus result) public {
        if(_addrMultisig == address(0)) {
            attachMultisig();
        }else {
            restart();
        }
    }
    function restart() public {
        if(_keyHandle == 0) {
            uint[] none;
            SigningBoxInput.get(tvm.functionId(setKeyHandle), "Enter your key for subsequent operations", none);
            return;
        }
        if(_allClasses.length==0){
            getAllRace();
            return;
        }

        NftRoot(_addrNFTRoot).getInfo{
            abiVer: 2,
            sign: false,
            pubkey: _pubkey,
            time: 0,
            expire: 0,
            extMsg:true,
            callbackId: tvm.functionId(checkContract),
            onErrorId:tvm.functionId(onError)
            }();
        //checkContract(_addrNFTRoot);
    }
    function checkContract(uint256 totalMinted,uint128 price) public {
        _totalMinted=totalMinted;
        MenuItem[] _items;
        Terminal.print(0, format("{} Heroes have been summoned,and Summoning one hero will cost you {:t} ton",totalMinted,price));
        _items.push(MenuItem("Recruit Heroes", "", tvm.functionId(checkPrice)));
        _items.push(MenuItem("Check My Team", "", tvm.functionId(getMyAllLoot)));
        _items.push(MenuItem("Roam Task", "", tvm.functionId(adventureSlct)));
        _items.push(MenuItem("Trans To", "", tvm.functionId(attachTransferAddr)));
        Menu.select("Choose your action:", "", _items);
    }

//-----------交易-----------
    function attachTransferAddr(uint32 index) public {
        AddressInput.get(tvm.functionId(transferSlct), "Please enter transfer to address:");
    }
    function transferSlct(address value) public{
        _transToAddr=value;
        if(_owners.length>0){
        MenuItem[] _items;
        Constants.Hero item;
        for (uint i = 0; i < _owners.length; i++) {
        item=_owners[i];
        _items.push(MenuItem(format("{} (Lv:{})",item.name,item.level), item.race, tvm.functionId(setTransferHero)));
        }
        Menu.select("Select Transfer Hero", "", _items);
        }else{
        Terminal.print(tvm.functionId(restart), "You don't have a hero,or please check the hero first");
        }

    }
    function setTransferHero(uint32 index)public{
        Constants.Hero item=_owners[index];
        //        Terminal.print(0, format("英雄Data地址：{}",addrData));
        TvmCell payload = tvm.encodeBody(
        Data.transferOwnership,_transToAddr
        );

        IMultisig(_addrMultisig).sendTransaction {
        abiVer: 2,
        sign: true,
        pubkey: _pubkey,
        time: 0,
        expire: 0,
        extMsg:true,
        callbackId: tvm.functionId(onTransfer),
        onErrorId: tvm.functionId(onError),
        signBoxHandle: _keyHandle
        }(item.dataAddr, 0.3 ton, true, 3,payload);
    }
    function onTransfer()public{
        Terminal.print(0, "Transfer Success");
        getMyAllLoot(0);
    }
//-----------交易 end-----------
//-----------游玩探险-----------
    function adventureSlct(uint32 index) public{
        if(_owners.length>0){
            MenuItem[] _items;
            Constants.Hero item;
            for (uint i = 0; i < _owners.length; i++) {
            item=_owners[i];
            _items.push(MenuItem(format("{} (Lv:{})",item.name,item.level), item.race, tvm.functionId(setSlctHero)));
            }
            Menu.select("Select Hero", "", _items);
        }else{
            Terminal.print(tvm.functionId(restart), "You don't have a hero,or please check the hero first");
        }

    }
    function setSlctHero(uint32 index)public{
        _tempHero=_owners[index];
//        Terminal.print(0, format("英雄Data地址：{}",addrData));
        TvmCell payload = tvm.encodeBody(
            Data.adventure
        );

        IMultisig(_addrMultisig).sendTransaction {
            abiVer: 2,
            sign: true,
            pubkey: _pubkey,
            time: 0,
            expire: 0,
            extMsg:true,
            callbackId: tvm.functionId(onAdventure),
            onErrorId: tvm.functionId(onError),
            signBoxHandle: _keyHandle
        }(_tempHero.dataAddr, 0.3 ton, true, 3,payload);

    }

    function onAdventure()public{
        Terminal.print(0, "Your hero came back from patrol,and gained 250 XPs.");

        MenuItem[] _items;
        _items.push(MenuItem("Level Up", "", tvm.functionId(levelUp)));
        _items.push(MenuItem("Assign Attr", "", tvm.functionId(assignAttr)));
        _items.push(MenuItem("Increase Str", "", tvm.functionId(assignAttr)));
        _items.push(MenuItem("Increase Dex", "", tvm.functionId(assignAttr)));
        _items.push(MenuItem("Increase Const", "", tvm.functionId(assignAttr)));
        _items.push(MenuItem("Increase Int", "", tvm.functionId(assignAttr)));
        _items.push(MenuItem("Increase Wis", "", tvm.functionId(assignAttr)));
        _items.push(MenuItem("Increase Cha", "", tvm.functionId(assignAttr)));
        _items.push(MenuItem("Check Ability", "", tvm.functionId(checkAbility)));
        _items.push(MenuItem("Back to main menu", "", tvm.functionId(restart)));
        Menu.select("Choose your action:", "", _items);
    }
    //-----------游玩探险 end-----------
    //-----------查看英雄能力值-----------
    function checkAbility(uint32 index)public{
        HeroAttributes(_attributeAddr).getAbilityScores{
            abiVer: 2,
            callbackId: tvm.functionId(onCheckAbility),
            onErrorId: 0,
            extMsg:true,
            time: 0,
            pubkey: _pubkey,
            expire: 0,
            sign: false
        } (_tempHero.dataAddr);
    }
    function onCheckAbility(HeroAttributes.ability_score score,address summoner)public{
       string info =format("{}\t#{}\n----------------------\n",_tempHero.name,_tempHero.id);
        info.append(format("strength:         {}\n",score.strength));
        info.append(format("dexterity:       {}\n",score.dexterity));
        info.append(format("constitution:    {}\n",score.constitution));
        info.append(format("intelligence:    {}\n",score.intelligence));
        info.append(format("wisdom:         {}\n",score.wisdom));
        info.append(format("charisma:      {}\n",score.charisma));
       // info.append(format("----------------------"));
        Terminal.print(tvm.functionId(onAdventure), info);
    }

    //-----------分配点数 属性操作-----------
    function assignAttr(uint32 index)public{
        //        Terminal.print(0, format("英雄Data地址：{}",addrData));
        TvmCell payload ;
        if(index==1){
            payload=tvm.encodeBody(
            HeroAttributes.point_buy,_tempHero.dataAddr,_tempHero.race,15,14,14,14,14,8
            );
        }else if(index==2){
            payload=tvm.encodeBody(
                HeroAttributes.increase_strength,_tempHero.dataAddr
            );
        }else if(index==3){
            payload=tvm.encodeBody(
            HeroAttributes.increase_dexterity,_tempHero.dataAddr
            );
        }else if(index==4){
            payload=tvm.encodeBody(
            HeroAttributes.increase_constitution,_tempHero.dataAddr
            );
        }else if(index==5){
            payload=tvm.encodeBody(
            HeroAttributes.increase_intelligence,_tempHero.dataAddr
            );
        }else if(index==6){
            payload=tvm.encodeBody(
            HeroAttributes.increase_wisdom,_tempHero.dataAddr
            );
        }else if(index==7){
            payload=tvm.encodeBody(
            HeroAttributes.increase_charisma,_tempHero.dataAddr
            );
        }

        IMultisig(_addrMultisig).sendTransaction {
        abiVer: 2,
        sign: true,
        pubkey: _pubkey,
        time: 0,
        expire: 0,
        extMsg:true,
        callbackId: tvm.functionId(onAdventure),
        onErrorId: tvm.functionId(onError),
        signBoxHandle: _keyHandle
        }(_attributeAddr, 0.3 ton, true, 3,payload);
    }
    //-----------升级-----------
    function levelUp(uint32 index)public{
        TvmCell payload = tvm.encodeBody(
        Data.level_up
        );

        IMultisig(_addrMultisig).sendTransaction {
        abiVer: 2,
        sign: true,
        pubkey: _pubkey,
        time: 0,
        expire: 0,
        extMsg:true,
        callbackId: tvm.functionId(onAdventure),
        onErrorId: tvm.functionId(onError),
        signBoxHandle: _keyHandle
        }(_tempHero.dataAddr, 0.3 ton, true, 3,payload);
    }
    //-----------升级 end-----------
    //-----------召唤新英雄-----------
        //当前召唤英雄价格
    function checkPrice(uint32 index) public{
        NftRoot(_addrNFTRoot).getPrice{
            abiVer: 2,
            sign: false,
            pubkey: _pubkey,
            time: 0,
            expire: 0,
            extMsg:true,
            callbackId: tvm.functionId(getCurrMintPrice),
            onErrorId:tvm.functionId(getCurrMintPriceError)
        }();
    }
    function getCurrMintPriceError(uint32 sdkError, uint32 exitCode) public {
        Terminal.print(0, format("getCurrMintPriceError Sdk error {}. Exit code {}.", sdkError, exitCode));
        restart();
    }
    function getCurrMintPrice(uint128 price)public{
        currMintPrice=math.max(price,3 ton);
        ConfirmInput.get(tvm.functionId(setConfirm), format("Summoning one hero will cost you {:t} ton,Continue?",currMintPrice));

    }
    function setConfirm(bool value) public {
        // TODO: continue here
        if(value){
            Sdk.getBalance(tvm.functionId(getUserPrice),_addrMultisig);
        }else{
            restart();
        }
    }
    function getUserPrice(uint128 nanotokens)public{
        if(currMintPrice>nanotokens){
            Terminal.print(0, format("Your balance is not enough to open a new backpack! You may currently need:{:t} ton",currMintPrice));
            restart();
        }else{
            chooseRace();
        }
    }
    //选择种族
    function chooseRace()public{
        MenuItem[] _items;
        for(uint8 i =0;i<_allRace.length;i++){
        _items.push(MenuItem(_allRace[i], "", tvm.functionId(setChooseRace)));
        }
        _items.push(MenuItem("Back to main menu", "", tvm.functionId(restart)));

        Menu.select("Select Your Race", "", _items);
    }
    function setChooseRace(uint32 index)public{
        _race=uint8(index);
        chooslGender();
    }
    //选择性别
    function chooslGender()public {
        MenuItem[] _items;
        _items.push(MenuItem("Female", "", tvm.functionId(setChooslGender)));
        _items.push(MenuItem("Male", "", tvm.functionId(setChooslGender)));
        _items.push(MenuItem("Back to main menu", "", tvm.functionId(restart)));

        Menu.select("Select Your Gender", "", _items);
    }
    function setChooslGender(uint32 index)public{
        _gender=uint8(index);
        chooseClass();
    }
    //选择职业
    function chooseClass()public{
        MenuItem[] _items;
        for(uint8 i =0;i<_allClasses.length;i++){
        _items.push(MenuItem(_allClasses[i], "", tvm.functionId(setChooseClass)));
        }
        _items.push(MenuItem("Back to main menu", "", tvm.functionId(restart)));

        Menu.select("Select Your Class", "", _items);
    }
    function setChooseClass(uint32 index)public{
        _class=uint8(index);
        nftParamsSetOwnerAddress();
    }

    function nftParamsSetOwnerAddress() public {
      //  Terminal.print(0, format("当前选择：_gender：{}，_race：{}，_class:{}",_gender,_race,_class));
        TvmCell payload = tvm.encodeBody(
            NftRoot.mintNft,_gender,_race+1,_class+1
        );
        IMultisig(_addrMultisig).sendTransaction {
        abiVer: 2,
        sign: true,
        pubkey: _pubkey,
        time: 0,
        expire: 0,
        extMsg:true,
        callbackId: tvm.functionId(mintSuccess),
       onErrorId: tvm.functionId(onError),
        signBoxHandle: _keyHandle
        }(_addrNFTRoot, currMintPrice, true, 3, payload);
    }

    function mintSuccess()public{
        Terminal.print(tvm.functionId(restart),"One hero has been summoned successfully by you");
    }
    //-----------召唤新英雄 end-----------
    //-----------查看英雄-----------

    function getMyAllLoot(uint32 index) public {
        index;
        delete _owners;
        TvmBuilder salt;
        if(index==uint32(3)){
            salt.store(address(0x0));
        }else{
            salt.store(_addrNFTRoot);
        }
        salt.store(_addrMultisig);
        TvmCell code = tvm.setCodeSalt(_codeIndex, salt.toCell());
        uint256 codeHash = tvm.hash(code);
       Sdk.getAccountsDataByHash(tvm.functionId(getIndexInfo), codeHash, address(0x0));
    }
    //index -> data -> storage
    function getIndexInfo(AccData[] accounts)public{
    Terminal.print(0,format("Current team of heroes:{}",accounts.length));
        for (uint i = 0; i < accounts.length; i++){
        Index(accounts[i].id).getInfo{
            abiVer: 2,
            callbackId: tvm.functionId(getDataInfo),
            onErrorId: 0,
            extMsg:true,
            time: 0,
            //pubkey: _pubkey,
            expire: 0,
            sign: false
            }();
        }
        this.printNftData();

    }
    function getDataInfo(address addrRoot,
        address addrOwner,
        address addrData)public{
       // Terminal.print(0,format("TonLoot背包Data地址：{}",addrData));
        Data(addrData).summoner{
            abiVer: 2,
            callbackId: tvm.functionId(setDataResult),
            onErrorId: 0,
            extMsg:true,
            time: 0,
            expire: 0,
            //pubkey: _pubkey,
            sign: false
            }();
    }

    function setDataResult(Constants.Hero _hero,address approvedAddr) public{
        _owners.push(_hero);
    }


    function printNftData() public {
        Constants.Hero item;
        for (uint i = 0; i < _owners.length; i++) {
            item=_owners[i];
            Terminal.print(0, _buildNftDataPrint(item));
        }
        Terminal.print(tvm.functionId(restart),"Back to main menu");
    }
    function _buildNftDataPrint(Constants.Hero _item) public returns (string str) {
             str = format("{}\t#{}\n----------------------\n",_item.name,_item.id);
        str.append(format("Race:     {}\n",_item.race));
        str.append(format("Gender: {}\n",_item.gender==1?"Male":"Female"));
        str.append(format("Class:    {}\n",_item.class));
        str.append(format("XP:         {}\n",_item.xp));
        str.append(format("Level:    {}\n",_item.level));
        str.append(format("dataAddr:    {}\n",_item.dataAddr));
        //str.append(format("ownerAddr:    {}\n",_item.ownerAddr));
        str.append(format("Next Roam: {}s\n",_item.adventurers_log>now?(_item.adventurers_log-now):0));
        str.append("----------------------");
        return str;
    }
    //-----------查看英雄 end-----------
    /*
    * helpers
    */

    function onError(uint32 sdkError, uint32 exitCode) public {
        Terminal.print(0, format("Sdk error {}. Exit code {}.", sdkError, exitCode));
        restart();
    }

    function attachMultisig() public {
        AddressInput.get(tvm.functionId(saveMultisig), "Please enter your address:");
    }

    function saveMultisig(address value) public {
        _addrMultisig = value;
        restart();
    }

    function setKeyHandle(uint32 handle) public {
        _keyHandle = handle;
        restart();
    }
    function getAllRace()public{
        NftRoot(_addrNFTRoot).getAllRace{
        abiVer: 2,
        sign: false,
        pubkey: _pubkey,
        time: 0,
        expire: 0,
        extMsg:true,
        callbackId: tvm.functionId(setAllRace),
        onErrorId:tvm.functionId(onError)
        }();
    }
    function setAllRace(string[] allRace)public{
        _allRace=allRace;
        getAllClasses();
    }
    function getAllClasses()public{
        NftRoot(_addrNFTRoot).getAllClasses{
        abiVer: 2,
        sign: false,
        pubkey: _pubkey,
        time: 0,
        expire: 0,
        extMsg:true,
        callbackId: tvm.functionId(setAllClasses),
        onErrorId:tvm.functionId(onError)
        }();
    }
    function setAllClasses(string[] allClasses)public{
        _allClasses=allClasses;
        restart();
    }


    function onCodeUpgrade() internal override {
        tvm.resetStorage();
    }

}
