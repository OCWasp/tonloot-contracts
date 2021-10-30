pragma ton-solidity >=0.43.0;

pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

import './resolvers/IndexResolver.sol';
import './resolvers/DataResolver.sol';
import './IndexBasis.sol';

import './interfaces/IData.sol';
import './interfaces/IIndexBasis.sol';
import "./interfaces/INftRoot.sol";

import "./libraries/Constants.sol";
import "../../components/debots/Interfaces/Upgradable.sol";

contract NftRoot is INftRoot, DataResolver, IndexResolver, Upgradable{
    //address static _addrOwner;

    string [] allClasses;//= ["Barbarian","Bard","Cleric","Druid","Fighter","Monk","Paladin","Ranger","Rogue","Sorcerer","Wizard"];

    string[]  allRace;//=["Dwarf","Hobbit","Elf","Human"];

    string[] _Dwarf_Male_Names;// ["Adrik","Alberich","Baern","Barendd","Brottor","Bruenor","Dain","Darrak","Delg","Eberk","Einkil","Fargrim","Flint","Gardain","Harbek","Kildrak","Morgran","Orsik","Oskar","Rangrim","Rurik","Taklinn","Thoradin","Thorin","Tordek","Traubon","Travok","Ulfgar","Veit","Vondal"];
    string[] _Dwarf_Female_Names;// ["Amber","Artin","Audhild","Bardryn","Dagnal","Diesa","Eldeth","Falkrunn","Finellen","Gunnloda","Gurdis","Helja","Hlin","Kathra","Kristryd","Ilde","Liftrasa","Mardred","Riswynn","Sannl","Torbera","Torgga","Vistra"];
    string[] _Dwarf_Clan_Names;// ["Balderk","Battlehammer","Brawnanvil","Dankil","Fireforge","Frostbeard","Gorunn","Holderhek","Ironfist","Loderr","Lutgehr","Rumnaheim","Strakeln","Torunn","Ungart"];

    string[] _Hobbit_Male_Names;// ["Alton","Ander","Cade","Corrin","Eldon","Errich","Finnan","Garret","Lindal","Lyle","Merric","Milo","Osborn","Perrin","Reed","Roscoe","Wellby"];
    string[] _Hobbit_Female_Names;// ["Andry","Bree","Callie","Cora","Euphemia","Jillian","Kithri","Lavinia","Lidda","Merla","Nedda","Paela","Portia","Seraphina","Shaena","Trym","Vani","Verna"];
    string[] _Hobbit_Clan_Names;// ["Brushgather","Goodbarrel","Greenbottle","High-hill","Hilltopple","Leagallow","Tealeaf","Thorngage","Tosscobble","Underbough"];

    string[] _Elf_Male_Names;// ["Adran","Aelar","Aramil","Arannis","Aust","Beiro","Berrian","Carric","Enialis","Erdan","Erevan","Galinndan","Hadarai","Heian","Himo","Immeral","Ivellios","Laucian","Mindartis","Paelias","Peren","Quarion","Riardon","Rolen","Soveliss","Thamior","Tharivol","Theren","Varis"];
    string[] _Elf_Female_Names;// ["Adrie","Althaea","Anastrianna","Andraste","Antinua","Bethrynna","Birel","Caelynn","Drusilia","Enna","Felosial","Ielenia","Jelenneth","Keyleth","Leshanna","Lia","Meriele","Mialee","Naivara","Quelenna","Quillathe","Sariel","Shanairra","Shava","Silaqui","Theirastra","Thia","Vadania","Valanthe","Xanaphia"];
    string[] _Elf_Clan_Names;// ["Amakiir","Amastacia","Galanodel","Holimion ","Ilphelkiir","Liadon","Meliamne ","Naïlo","Siannodel","Xiloscient"];

    string[] _Human_Male_Names;
    string[] _Human_Female_Names;
    string[] _Human_Clan_Names;

    uint256 _totalMinted=1;
    address public _addrBasis;
    address public _beneficiary;

    mapping(uint256=>address) nftDataAddr;
    event summoned(address  owner, uint8 class, uint summoner);


    constructor(TvmCell codeIndex, TvmCell codeData, address beneficiary) public {
        tvm.accept();
        _codeIndex = codeIndex;
        _codeData = codeData;
        _beneficiary=beneficiary;
    }
    function setHumanNames(string[] maleNames,string[] femaleNames,string [] clanNames)public{
        require(msg.pubkey() == tvm.pubkey(), 102);
        tvm.accept();
        _Human_Male_Names=maleNames;
        _Human_Female_Names=femaleNames;
        _Human_Clan_Names=clanNames;
    }
    function setElfNames(string[] maleNames,string[] femaleNames,string [] clanNames)public{
        require(msg.pubkey() == tvm.pubkey(), 102);
        tvm.accept();
        _Elf_Male_Names=maleNames;
        _Elf_Female_Names=femaleNames;
        _Elf_Clan_Names=clanNames;
    }
    function setHobbitNames(string[] maleNames,string[] femaleNames,string [] clanNames)public{
        require(msg.pubkey() == tvm.pubkey(), 102);
        tvm.accept();
        _Hobbit_Male_Names=maleNames;
        _Hobbit_Female_Names=femaleNames;
        _Hobbit_Clan_Names=clanNames;
    }

    function setDwarfNames(string[] maleNames,string[] femaleNames,string [] clanNames)public{
        require(msg.pubkey() == tvm.pubkey(), 102);
        tvm.accept();
        _Dwarf_Male_Names=maleNames;
        _Dwarf_Female_Names=femaleNames;
        _Dwarf_Clan_Names=clanNames;
    }

    function setRaceAndClass(string [] _allRace,string [] _allClasses)public{
        require(msg.pubkey() == tvm.pubkey(), 102);
        tvm.accept();
        allClasses=_allClasses;
        allRace=_allRace;
    }

    function mintNft(uint8 _gender,uint8 _race,uint8 _class) public override returns (uint256 tokenId){
        require(msg.sender != address(0x0), Constants.err_sender_0);
        require(1<=_race&&_race<=allRace.length,Constants.err_race_limit);
        require(1 <= _class && _class <= 11,Constants.err_class_limit);
        uint128 currPrice= getPrice();
        require(msg.value >= currPrice, Constants.err_price_mint);


       tvm.accept();
        address addrData = resolveData(address(this), _totalMinted);
        // _beneficiary==>owner
        TvmCell codeData = _buildDataCode(address(this));
        TvmCell stateData = _buildDataState(codeData, _totalMinted);


        string raceName=allRace[_race-1];
        string _name= randomHeroName(raceName,_gender==1);
        rnd.shuffle();
        uint8 _imgNum = rnd.next(uint8(50));

        Constants.Hero hero=Constants.Hero({id:_totalMinted,name:_name,gender:_gender,
            race:raceName,imgNum:_imgNum,xp:0,adventurers_log:0,
            class:classes(_class),level:1,dataAddr:addrData,ownerAddr:msg.sender,createTime:now
            });

        new Data{
            stateInit: stateData,
            value: 0.5 ton
        }(msg.sender, hero,_codeIndex);

        //_beneficiary.transfer(0,true,64);
        tokenId=_totalMinted;
        nftDataAddr[tokenId]=addrData;
        emit summoned(msg.sender, _class, _totalMinted);
        _totalMinted++;
    }
    function getPrice() public view returns(uint128 price){
        price=5 ton;
    }

    function deployBasis(TvmCell codeIndexBasis) public override {
        //require(msg.sender == _addrOwner, 100);
        require(msg.pubkey() == tvm.pubkey(), 102);
        tvm.accept();
        uint256 codeHasData = resolveCodeHashData();
        TvmCell state = tvm.buildStateInit({
            contr: IndexBasis,
            varInit: {
                _codeHashData: codeHasData,
                _addrRoot: address(this)
            },
            code: codeIndexBasis
        });
        _addrBasis = new IndexBasis{stateInit: state, value: 0.1 ton}();
    }

    function destructBasis() public override view {
      //  require(msg.sender == _addrOwner, 100);
        IIndexBasis(_addrBasis).destruct();
    }

    function getInfo() public override view returns (uint256 totalMinted,uint128 price) {
        totalMinted = _totalMinted-1;
        price=getPrice();
    }

    function withdraw()public{
        require(address(this).balance > 1 ton, 501);
        tvm.accept();
        _beneficiary.transfer(address(this).balance-1 ton);
    }

    function randomHeroName(string race,bool male) internal view returns(string name){
        if("Dwarf"==race){
            if(male){
                name=format("{} {}",randomByNames(_Dwarf_Male_Names),randomByNames(_Dwarf_Clan_Names));
            }else{
                name=format("{} {}",randomByNames(_Dwarf_Female_Names),randomByNames(_Dwarf_Clan_Names));
            }
        }else if("Halfling"==race){
            if(male){
                name=format("{} {}",randomByNames(_Hobbit_Male_Names),randomByNames(_Hobbit_Clan_Names));
            }else{
                name=format("{} {}",randomByNames(_Hobbit_Female_Names),randomByNames(_Hobbit_Clan_Names));
            }
        }else if("Elf"==race){
            if(male){
                name=format("{} {}",randomByNames(_Elf_Male_Names),randomByNames(_Elf_Clan_Names));
            }else{
                name=format("{} {}",randomByNames(_Elf_Female_Names),randomByNames(_Elf_Clan_Names));
            }
        }else if("Human"==race){
            if(male){
                name=format("{} {}",randomByNames(_Human_Male_Names),randomByNames(_Human_Clan_Names));
            }else{
                name=format("{} {}",randomByNames(_Human_Female_Names),randomByNames(_Human_Clan_Names));
            }
        }
    }
    function randomByNames(string[]names)pure internal returns(string name){
        rnd.shuffle();
        uint r2 = rnd.next(names.length);
        name=names[r2];
    }

    function classes(uint8 id) public responsible view returns (string  description) {
        description=allClasses[id-1];
    }
    function getAllClasses()public view returns(string [] _allClasses){
        _allClasses= allClasses;
    }
    function getAllRace()public view returns(string [] _allRace){
        _allRace= allRace;
    }
    fallback() external {
    }
    function onCodeUpgrade() internal override {

    }
}
